#!/usr/bin/env python3
"""Exercise the real curl/prlimit path against an isolated localhost HTTPS server."""
import gzip
import http.server
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import tempfile
import threading
import time
import unittest
from unittest import mock

from test_network_fallback import nf, PROBE


class ProbeHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *args):
        pass

    def handle(self):
        try:
            super().handle()
        except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
            # Expected when the client rejects the certificate or stops an oversized body.
            pass

    def do_GET(self):
        self.server.encodings.append(self.headers.get('Accept-Encoding'))
        body = PROBE
        if self.path == '/short':
            body = PROBE[:16384]
        elif self.path == '/wrong-hash':
            body = bytes([PROBE[0] ^ 1]) + PROBE[1:]
        elif self.path == '/gzip':
            body = gzip.compress(PROBE)
        self.send_response(206 if self.path == '/partial' else 200)
        self.send_header('Connection', 'close')
        if self.path == '/gzip':
            self.send_header('Content-Encoding', 'gzip')
        if self.path == '/partial':
            self.send_header('Content-Range', 'bytes 0-1048575/1048576')
        if self.path in ('/chunked', '/overflow'):
            self.send_header('Transfer-Encoding', 'chunked')
        elif self.path != '/streamed':
            self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        try:
            if self.path in ('/chunked', '/overflow'):
                content = PROBE if self.path == '/chunked' else PROBE * 2
                for offset in range(0, len(content), 65536):
                    chunk = content[offset:offset + 65536]
                    self.wfile.write(('{:x}\r\n'.format(len(chunk))).encode() + chunk + b'\r\n')
                self.wfile.write(b'0\r\n\r\n')
            else:
                self.wfile.write(body[:16384] if self.path == '/truncated' else body)
                if self.path == '/streamed':
                    # Close-delimited HTTPS needs a clean TLS EOF, not an abrupt TCP close.
                    self.wfile.flush()
                    self.connection.settimeout(2)
                    self.connection.unwrap()
        except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
            pass
        self.close_connection = True


@unittest.skipUnless(all(shutil.which(tool) for tool in ('curl', 'openssl', 'prlimit')),
                     'curl, openssl and prlimit are required for HTTPS integration tests')
class HTTPSProbeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='minios-probe-https-')
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.work = Path(cls.temporary.name)
        cert, key = cls.work / 'cert.pem', cls.work / 'key.pem'
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                        '-keyout', str(key), '-out', str(cert), '-days', '1',
                        '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost'],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        cls.server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), ProbeHandler)
        cls.server.encodings = []
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert, key)
        cls.server.socket = context.wrap_socket(cls.server.socket, server_side=True)
        cls.worker = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.worker.start()
        cls.addClassCleanup(cls.stop_server)
        env = mock.patch.dict(os.environ, {'CURL_CA_BUNDLE': str(cert)})
        env.start()
        cls.addClassCleanup(env.stop)

    @classmethod
    def stop_server(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.worker.join(timeout=5)

    def setUp(self):
        temp = tempfile.TemporaryDirectory(dir=self.work)
        self.addCleanup(temp.cleanup)
        work = Path(temp.name)
        hosts = work / 'hosts'
        hosts.write_text('127.0.0.1 localhost\n')
        self.fallback = nf.Fallback(hosts, work / 'state')
        self.fallback.register()
        self.fallback.deadline = time.monotonic() + 60
        patch = mock.patch.object(nf, 'log')
        patch.start()
        self.addCleanup(patch.stop)

    def request(self, path, host='localhost'):
        return self.fallback.request(host, 'https://{}:{}{}'.format(host, self.server.server_port, path))

    def test_full_file_with_content_length(self):
        self.assertIs(nf.valid_probe(*self.request('/valid')), True)

    def test_full_file_without_content_length(self):
        self.assertIs(nf.valid_probe(*self.request('/streamed')), True)

    def test_full_file_with_chunked_encoding(self):
        self.assertIs(nf.valid_probe(*self.request('/chunked')), True)

    def test_short_success_response_is_rejected(self):
        self.assertIsNone(nf.valid_probe(*self.request('/short')))

    def test_truncated_transfer_is_rejected(self):
        self.assertIsNone(self.request('/truncated'))

    def test_same_size_wrong_hash_is_rejected(self):
        self.assertIsNone(nf.valid_probe(*self.request('/wrong-hash')))

    def test_partial_response_is_rejected(self):
        self.assertIsNone(nf.valid_probe(*self.request('/partial')))

    def test_gzip_representation_is_rejected(self):
        result = self.request('/gzip')
        self.assertFalse(result and nf.valid_probe(*result))

    def test_oversize_chunked_transfer_is_bounded_and_rejected(self):
        self.assertIsNone(self.request('/overflow'))
        self.assertEqual(list(self.fallback.state.glob('probe-*')), [])

    def test_tls_hostname_mismatch_is_rejected(self):
        self.assertIsNone(self.request('/valid', host='127.0.0.1'))

    def test_identity_encoding_is_requested(self):
        self.request('/valid')
        self.assertTrue(self.server.encodings)
        self.assertTrue(all(value == 'identity' for value in self.server.encodings))


if __name__ == '__main__':
    unittest.main()
