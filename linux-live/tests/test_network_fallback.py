#!/usr/bin/python3
"""Regression tests for the MiniOS network dispatcher, using isolated hosts files."""
import concurrent.futures
import gzip
import hashlib
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
ROOTCOPY = ROOT / 'scripts/00-core/rootcopy-install'
HOOK = ROOTCOPY / 'etc/NetworkManager/dispatcher.d/no-wait.d/90-minios-network'
CONFIG = ROOTCOPY / 'etc/minios/network-fallback.json'
loader = importlib.machinery.SourceFileLoader('network_fallback', str(HOOK))
spec = importlib.util.spec_from_loader(loader.name, loader)
nf = importlib.util.module_from_spec(spec)
previous_bytecode_setting = sys.dont_write_bytecode
sys.dont_write_bytecode = True
try:
    loader.exec_module(nf)
finally:
    sys.dont_write_bytecode = previous_bytecode_setting
NORMAL = b'127.0.0.1 localhost\n::1 localhost ip6-localhost\n# Keep this comment\n'
IP = '185.199.109.133'
ASSET_URL = 'https://' + nf.ASSETS + '/github-production-release-asset/1/probe?sig=fresh'
PROBE = hashlib.shake_256(b'MiniOS network connectivity probe v1\n').digest(1024 * 1024)


def block(host=nf.ASSETS, ip=IP):
    return nf.BEGIN + b'\n' + (ip + ' ' + host + '\n').encode() + nf.END + b'\n'


class FallbackTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.hosts = self.root / 'hosts'
        self.hosts.write_bytes(NORMAL)
        self.hosts.chmod(0o640)
        self.config = self.root / 'config.json'
        self.config.write_bytes(CONFIG.read_bytes())
        self.fallback = nf.Fallback(self.hosts, self.root / 'run', self.config)
        self.logger = mock.patch.object(nf, 'log').start()
        self.addCleanup(mock.patch.stopall)

    def activate(self):
        self.fallback.register()
        self.fallback.deadline = time.monotonic() + 40
        self.fallback.load_config()

    def test_remove_only_own_block_preserving_other_bytes(self):
        source = b'# user header\r\n' + block() + NORMAL + b'192.0.2.1 private'
        clean, manual, previous = nf.split_hosts(source)
        self.assertEqual(clean, source.replace(block(), b''))
        self.assertIn('private', manual)
        self.assertEqual(previous[nf.ASSETS], IP)

    def test_malformed_blocks_fail_without_deleting_tail(self):
        for source in (nf.BEGIN + b'\n' + NORMAL, nf.END + b'\n' + NORMAL,
                       nf.BEGIN + b'\n' + block()):
            with self.subTest(source=source), self.assertRaises(ValueError):
                nf.split_hosts(source)

    def test_manual_aliases_are_case_insensitive(self):
        self.hosts.write_bytes(NORMAL + b'192.0.2.5 Other RELEASE-ASSETS.GITHUBUSERCONTENT.COM.\n')
        self.activate()
        self.assertIn(nf.ASSETS, self.fallback.manual)
        with self.fallback.locked():
            applied = self.fallback.write_hosts({nf.ASSETS: IP})
        self.assertEqual(applied, {})
        self.assertNotIn(nf.BEGIN, self.hosts.read_bytes())

    def test_registration_clears_previous_boot_and_invalidates_older_worker(self):
        self.hosts.write_bytes(block() + NORMAL)
        self.activate()
        self.assertEqual(self.hosts.read_bytes(), NORMAL)
        self.assertEqual(self.fallback.previous[nf.ASSETS], IP)
        later = nf.Fallback(self.hosts, self.root / 'run', self.config)
        later.register()
        self.assertFalse(self.fallback.current())
        self.assertTrue(later.current())

    def test_round_trip_preserves_no_final_newline(self):
        original = NORMAL.rstrip(b'\n')
        self.hosts.write_bytes(original)
        self.activate()
        with self.fallback.locked():
            self.fallback.write_hosts({nf.ASSETS: IP})
            self.fallback.write_hosts({})
        self.assertEqual(self.hosts.read_bytes(), original)

    def test_atomic_write_preserves_mode_owner_and_refreshes_mtime(self):
        os.utime(self.hosts, (1, 1))
        before = self.hosts.stat()
        self.activate()
        with self.fallback.locked():
            self.fallback.write_hosts({nf.ASSETS: IP})
        after = self.hosts.stat()
        self.assertEqual(after.st_mode, before.st_mode)
        self.assertEqual(after.st_uid, before.st_uid)
        self.assertEqual(after.st_gid, before.st_gid)
        self.assertGreater(after.st_mtime_ns, before.st_mtime_ns)
        self.assertNotEqual(after.st_ino, before.st_ino)

    def test_no_rewrite_if_hosts_unchanged(self):
        self.activate()
        before = self.hosts.stat()
        with self.fallback.locked():
            self.fallback.write_hosts({})
        after = self.hosts.stat()
        self.assertEqual(after.st_ino, before.st_ino)
        self.assertEqual(after.st_mtime_ns, before.st_mtime_ns)

    def test_manual_changes_during_probes_are_preserved(self):
        self.activate()
        edited = NORMAL + b'192.0.2.6 store.minios.dev user-server\n'
        self.hosts.write_bytes(edited)
        with self.fallback.locked():
            applied = self.fallback.write_hosts({'store.minios.dev': '185.199.108.153', nf.ASSETS: IP})
        self.assertEqual(applied, {nf.ASSETS: IP})
        self.assertEqual(nf.split_hosts(self.hosts.read_bytes())[0], edited)

    def test_symlink_hosts_target_is_preserved(self):
        target = self.root / 'real-hosts'
        self.hosts.rename(target)
        self.hosts.symlink_to(target)
        self.activate()
        with self.fallback.locked():
            self.fallback.write_hosts({nf.ASSETS: IP})
        self.assertTrue(self.hosts.is_symlink())
        self.assertIn(nf.BEGIN, target.read_bytes())

    def test_invalid_config_is_not_used(self):
        for update in ({'enabled': 'yes'}, {'candidates': {'evil.example': [IP]}},
                       {'candidates': {nf.ASSETS: ['127.0.0.1']}},
                       {'release_probe_url': 'http://github.com/unsafe.iso.sha256'}):
            cfg = json.loads(CONFIG.read_text())
            cfg.update(update)
            self.config.write_text(json.dumps(cfg))
            with self.subTest(update=update), self.assertRaises(ValueError):
                self.fallback.load_config()

    def test_disabled_configuration_still_removes_old_entries(self):
        self.hosts.write_bytes(block() + NORMAL)
        self.config.write_text('{"enabled": false}')
        with mock.patch.object(nf.time, 'sleep'), mock.patch.object(self.fallback, 'snapshot') as snapshot:
            self.fallback.run()
        self.assertEqual(self.hosts.read_bytes(), NORMAL)
        snapshot.assert_not_called()

    def test_clear_does_not_require_working_config_or_network(self):
        self.hosts.write_bytes(block() + NORMAL)
        self.config.unlink()
        with mock.patch.object(self.fallback, 'snapshot') as snapshot:
            self.fallback.run(clear=True)
        self.assertEqual(self.hosts.read_bytes(), NORMAL)
        snapshot.assert_not_called()

    def test_healthy_dns_does_not_try_candidates(self):
        self.activate()
        with mock.patch.object(self.fallback, 'request', return_value=(200, {}, PROBE)), \
                mock.patch.object(self.fallback, 'addresses') as addresses:
            ip, value = self.fallback.select(nf.ASSETS, ASSET_URL,
                                            nf.valid_probe)
        self.assertIsNone(ip)
        self.assertIs(value, True)
        addresses.assert_not_called()

    def test_failed_dns_uses_only_validated_alternative(self):
        self.activate()
        def request(host, url, ip=None, head=False):
            return (200, {}, PROBE) if ip == IP else (403, {}, b'blocked')
        with mock.patch.object(self.fallback, 'request', side_effect=request), \
                mock.patch.object(self.fallback, 'addresses', return_value=['185.199.108.133', IP]):
            ip, value = self.fallback.select(nf.ASSETS, ASSET_URL,
                                            nf.valid_probe)
        self.assertEqual(ip, IP)
        self.assertIs(value, True)

    def test_failure_does_not_leave_unverified_address(self):
        self.activate()
        with mock.patch.object(self.fallback, 'request', return_value=None), \
                mock.patch.object(self.fallback, 'addresses', return_value=[IP]):
            self.assertEqual(self.fallback.select(nf.ASSETS, ASSET_URL, nf.valid_redirect), (None, None))
        self.assertEqual(self.hosts.read_bytes(), NORMAL)

    def test_manual_host_never_triggers_alternative_probe(self):
        self.activate()
        self.fallback.manual.add(nf.ASSETS)
        with mock.patch.object(self.fallback, 'request', return_value=None), \
                mock.patch.object(self.fallback, 'addresses') as addresses:
            self.fallback.select(nf.ASSETS, ASSET_URL, nf.valid_redirect)
        addresses.assert_not_called()

    def test_getent_candidates_deduplicated_and_private_addresses_rejected(self):
        self.activate()
        self.fallback.previous = {nf.ASSETS: IP}
        output = (IP + ' STREAM host\n' + IP + ' DGRAM\n127.0.0.1 STREAM\n'
                  '2606:50c0:8000::154 STREAM\n').encode()
        with mock.patch.object(self.fallback, 'command', return_value=subprocess.CompletedProcess([], 0, output)):
            values = self.fallback.addresses(nf.ASSETS)
        self.assertEqual(values.count(IP), 1)
        self.assertNotIn('127.0.0.1', values)
        self.assertIn('2606:50c0:8000::154', values)

    def test_curl_checks_tls_bypasses_proxies_and_formats_ipv6(self):
        self.activate()
        def command(args, timeout):
            self.assertEqual(args[:4], ['prlimit', '--fsize=1048577:1048577', '--core=0:0', '--'])
            self.assertEqual(args[4:6], ['curl', '-q'])
            self.assertIn('Accept-Encoding: identity', args)
            self.assertEqual(args[args.index('--max-filesize') + 1], '1048577')
            self.assertEqual(args[args.index('--max-time') + 1], '30')
            self.assertEqual(args[args.index('--connect-timeout') + 1], '5')
            self.assertEqual(args[args.index('--noproxy') + 1], '*')
            self.assertEqual(args[args.index('--proto') + 1], '=https')
            self.assertNotIn('-k', args)
            self.assertNotIn('--insecure', args)
            self.assertNotIn('--location', args)
            self.assertIn(nf.ASSETS + ':443:[2606:50c0:8000::154]', args)
            Path(args[args.index('--dump-header') + 1]).write_bytes(b'HTTP/2 200\r\ncontent-type: text/plain\r\n\r\n')
            Path(args[args.index('--output') + 1]).write_bytes(PROBE)
            return subprocess.CompletedProcess(args, 0, b'200')
        with mock.patch.object(self.fallback, 'command', side_effect=command):
            self.assertEqual(self.fallback.request(nf.ASSETS, ASSET_URL, '2606:50c0:8000::154'),
                             (200, {'content-type': 'text/plain'}, PROBE))

    def test_tls_failure_is_not_success(self):
        self.activate()
        with mock.patch.object(self.fallback, 'command', return_value=subprocess.CompletedProcess([], 60, b'000')):
            self.assertIsNone(self.fallback.request(nf.ASSETS, ASSET_URL, IP))

    def test_release_uses_fresh_redirect_then_synthetic_probe(self):
        self.activate()
        with mock.patch.object(self.fallback, 'select', side_effect=[(None, ASSET_URL), (IP, True)]) as select:
            result = self.fallback.release(json.loads(CONFIG.read_text())['release_probe_url'])
        self.assertEqual(result, {nf.ASSETS: IP})
        self.assertEqual(select.call_args_list[1].args[1], ASSET_URL)
        self.assertTrue(select.call_args_list[0].kwargs['head'])

    def test_bad_redirect_does_not_probe_cdn_root(self):
        self.activate()
        with mock.patch.object(self.fallback, 'select', return_value=(None, None)) as select:
            result = self.fallback.release('https://github.com/check')
        self.assertEqual(result, {})
        self.assertEqual(select.call_count, 1)

    def test_changed_network_discards_successful_results(self):
        with mock.patch.object(nf.time, 'sleep'), \
                mock.patch.object(self.fallback, 'snapshot', side_effect=['old-network', 'new-network']), \
                mock.patch.object(self.fallback, 'page', return_value={}), \
                mock.patch.object(self.fallback, 'release', return_value={nf.ASSETS: IP}):
            self.fallback.run()
        self.assertEqual(self.hosts.read_bytes(), NORMAL)

    def test_unchanged_network_applies_results(self):
        with mock.patch.object(nf.time, 'sleep'), \
                mock.patch.object(self.fallback, 'snapshot', return_value='same-network'), \
                mock.patch.object(self.fallback, 'page', return_value={}), \
                mock.patch.object(self.fallback, 'release', return_value={nf.ASSETS: IP}):
            self.fallback.run()
        self.assertEqual(self.hosts.read_bytes(), block() + NORMAL)

    def test_new_event_wins_over_running_old_probe(self):
        ready, finish = threading.Event(), threading.Event()
        def release(url):
            ready.set()
            if not finish.wait(3):
                raise RuntimeError('test worker timed out')
            return {nf.ASSETS: IP}
        later = nf.Fallback(self.hosts, self.root / 'run', self.config)
        with mock.patch.object(nf.time, 'sleep'), \
                mock.patch.object(self.fallback, 'snapshot', return_value='same-network'), \
                mock.patch.object(self.fallback, 'page', return_value={}), \
                mock.patch.object(self.fallback, 'release', side_effect=release), \
                concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            running = pool.submit(self.fallback.run)
            try:
                self.assertTrue(ready.wait(3))
                later.run(clear=True)
            finally:
                finish.set()
            running.result(timeout=3)
        self.assertEqual(self.hosts.read_bytes(), NORMAL)
        self.assertTrue(later.current())

    def test_timeout_stops_subprocess_and_does_not_retry_unbounded(self):
        self.activate()
        with mock.patch.object(nf.subprocess, 'run', side_effect=subprocess.TimeoutExpired('curl', 1)):
            self.assertIsNone(self.fallback.command(['curl'], 1))
        self.fallback.deadline = time.monotonic() - 1
        with mock.patch.object(nf.subprocess, 'run') as run:
            self.assertIsNone(self.fallback.command(['curl'], 1))
        run.assert_not_called()

    def test_snapshot_ignores_lifetimes_not_addresses_or_routes(self):
        self.activate()
        lifetime = [100]
        address = ['192.0.2.10']
        def command(args, seconds):
            if 'address' in args:
                rows = [{'ifname': 'eth0', 'flags': ['UP'], 'addr_info': [
                    {'local': address[0], 'prefixlen': 24, 'scope': 'global', 'valid_life_time': lifetime[0]}]}]
            elif 'route' in args:
                rows = [{'dst': 'default', 'gateway': '192.0.2.1', 'expires': lifetime[0]}]
            else:
                rows = [{'priority': 32766, 'table': 'main'}]
            return subprocess.CompletedProcess(args, 0, json.dumps(rows).encode())
        with mock.patch.object(self.fallback, 'command', side_effect=command):
            before = self.fallback.snapshot()
            lifetime[0] = 99
            self.assertEqual(self.fallback.snapshot(), before)
            address[0] = '192.0.2.11'
            self.assertNotEqual(self.fallback.snapshot(), before)

    def test_small_dns_response_does_not_hide_blocked_bulk_transfer(self):
        self.activate()
        def request(host, url, ip=None, head=False):
            return (200, {}, PROBE if ip == IP else PROBE[:16384])
        with mock.patch.object(self.fallback, 'request', side_effect=request), \
                mock.patch.object(self.fallback, 'addresses', return_value=[IP]):
            ip, value = self.fallback.select(nf.ASSETS, ASSET_URL, nf.valid_probe)
        self.assertEqual(ip, IP)
        self.assertIs(value, True)

    def test_probe_failure_log_does_not_leak_signed_url(self):
        self.activate()
        with mock.patch.object(self.fallback, 'command', return_value=subprocess.CompletedProcess([], 60, b'000')):
            self.assertIsNone(self.fallback.request(nf.ASSETS, ASSET_URL, IP))
        messages = ' '.join(str(call) for call in self.logger.call_args_list)
        self.assertIn('curl=60', messages)
        self.assertIn('received=0 bytes', messages)
        self.assertNotIn('sig=fresh', messages)

    def test_redirect_uses_shorter_timeout_and_no_body_download(self):
        self.activate()
        def command(args, seconds):
            self.assertIn('--head', args)
            self.assertEqual(args[args.index('--max-time') + 1], '8')
            Path(args[args.index('--dump-header') + 1]).write_text('HTTP/2 302\r\nlocation: ' + ASSET_URL + '\r\n\r\n')
            Path(args[args.index('--output') + 1]).write_bytes(b'')
            return subprocess.CompletedProcess(args, 0, b'302')
        with mock.patch.object(self.fallback, 'command', side_effect=command):
            result = self.fallback.request('github.com', json.loads(CONFIG.read_text())['release_probe_url'], head=True)
        self.assertEqual(nf.valid_redirect(*result), ASSET_URL)


class ContractTests(unittest.TestCase):
    def test_dispatcher_link_is_no_wait_and_executable(self):
        link = HOOK.parent.parent / '90-minios-network'
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.resolve(), HOOK.resolve())
        self.assertTrue(os.access(HOOK, os.X_OK))
        self.assertEqual(HOOK.stat().st_mode & 0o022, 0)

    def test_runtime_dependencies_are_explicit_in_core(self):
        packages = (ROOT / 'scripts/00-core/packages.list').read_text().splitlines()
        for package in ('network-manager', 'python3', 'curl', 'ca-certificates', 'iproute2', 'util-linux'):
            self.assertIn(package, packages)

    def test_unsupported_event_does_nothing_even_without_root(self):
        with mock.patch.object(nf.os, 'geteuid', return_value=1000), \
                mock.patch.object(nf, 'Fallback') as fallback:
            self.assertEqual(nf.main(['eth0', 'pre-up']), 0)
        fallback.assert_not_called()

    def test_redirect_rejects_other_hosts_http_credentials_and_root(self):
        for location in ('http://' + nf.ASSETS + '/github-production-release-asset/1',
                         'https://' + nf.ASSETS + '.evil.test/github-production-release-asset/1',
                         'https://user@' + nf.ASSETS + '/github-production-release-asset/1',
                         'https://' + nf.ASSETS + '/'):
            self.assertIsNone(nf.valid_redirect(302, {'location': location}, b''))
        self.assertEqual(nf.valid_redirect(302, {'location': ASSET_URL}, b''), ASSET_URL)

    def test_synthetic_probe_requires_exact_bytes_not_just_http_200(self):
        for body in (b'', b'<html>Access denied</html>', PROBE[:16384], PROBE[:-1],
                     PROBE + b'x', b'0' * nf.PROBE_SIZE, PROBE[:-1] + bytes([PROBE[-1] ^ 1])):
            with self.subTest(length=len(body)):
                self.assertIsNone(nf.valid_probe(200, {}, body))
        self.assertIs(nf.valid_probe(200, {}, PROBE), True)

    def test_partial_and_error_statuses_are_rejected(self):
        for status in (206, 301, 302, 304, 403, 404, 500):
            with self.subTest(status=status):
                self.assertIsNone(nf.valid_probe(status, {}, PROBE))
        self.assertIsNone(nf.valid_probe(200, {'content-range': 'bytes 0-1048575/1048576'}, PROBE))

    def test_compressed_responses_are_rejected(self):
        for encoding in ('gzip', 'br', 'deflate', 'identity, gzip'):
            with self.subTest(encoding=encoding):
                self.assertIsNone(nf.valid_probe(200, {'content-encoding': encoding}, PROBE))
        self.assertIs(nf.valid_probe(200, {'content-encoding': 'identity'}, PROBE), True)

    def test_content_length_must_match_if_present(self):
        for value in ('16384', '1048575', '1048577', 'invalid', '-1', ''):
            with self.subTest(value=value):
                self.assertIsNone(nf.valid_probe(200, {'content-length': value}, PROBE))
        self.assertIs(nf.valid_probe(200, {'content-length': str(len(PROBE))}, PROBE), True)

    def test_probe_payload_is_reproducible_and_poorly_compressible(self):
        self.assertEqual(len(PROBE), nf.PROBE_SIZE)
        self.assertEqual(hashlib.sha256(PROBE).hexdigest(), nf.PROBE_SHA256)
        self.assertGreater(len(gzip.compress(PROBE)), len(PROBE) * 0.99)
        generator = ROOT.parent / 'tools/generate-network-probe.py'
        with tempfile.TemporaryDirectory() as work:
            subprocess.run([sys.executable, str(generator), work], check=True, capture_output=True)
            self.assertEqual((Path(work) / nf.PROBE_NAME).read_bytes(), PROBE)
            digest_line = (Path(work) / (nf.PROBE_NAME + '.sha256')).read_text()
            self.assertEqual(digest_line, nf.PROBE_SHA256 + '  ' + nf.PROBE_NAME + '\n')

    def test_sites_use_dedicated_versioned_probe(self):
        for path in nf.PAGES.values():
            self.assertEqual(path, '/network-check/v1/' + nf.PROBE_NAME)
        url = json.loads(CONFIG.read_text())['release_probe_url']
        self.assertTrue(url.endswith('/' + nf.PROBE_NAME))
        self.assertNotIn('.iso', url)

    def test_static_website_and_store_payloads_match_runtime_contract(self):
        for relative in ('submodules/minios-linux.github.io/public',
                         'submodules/minios-store/web/public'):
            path = ROOT.parent / relative / nf.PROBE_PATH.lstrip('/')
            with self.subTest(path=path):
                self.assertEqual(path.read_bytes(), PROBE)


    def test_generator_does_not_overwrite_changed_versioned_content(self):
        generator = ROOT.parent / 'tools/generate-network-probe.py'
        with tempfile.TemporaryDirectory() as work:
            path = Path(work) / nf.PROBE_NAME
            path.write_bytes(b'locally changed')
            result = subprocess.run([sys.executable, str(generator), work], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(path.read_bytes(), b'locally changed')

    def test_kernel_download_limit_works_without_content_length(self):
        with tempfile.TemporaryDirectory() as work:
            path = Path(work) / 'oversized'
            code = 'import pathlib,sys; pathlib.Path(sys.argv[1]).write_bytes(b"x" * 8192)'
            result = subprocess.run(['prlimit', '--fsize=4096:4096', '--core=0:0', '--',
                                     sys.executable, '-c', code, str(path)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertLessEqual(path.stat().st_size, 4096)



if __name__ == '__main__':
    unittest.main()
