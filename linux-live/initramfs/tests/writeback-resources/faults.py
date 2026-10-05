"""Run in a disposable RAM root session; exercise real freeze and publication."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

sys.path.insert(0, '/usr/lib/minios-session-manager')
import minios_ram_store
from minios_session import SessionManager

RUNTIME = Path('/run/initramfs/minios-persistence')


def writer(cancel):
    saver = minios_ram_store.RamSessionSave(SessionManager())
    original = saver.tools.copy_container_file

    def slow_copy(source, target, progress=None, cancelled=None):
        def report(count, total):
            if progress:
                progress(count, total)
            time.sleep(.1)
        return original(source, target, report, cancelled)

    saver.tools.copy_container_file = slow_copy
    saver.save('1', cancel_path=cancel)


def wait_copy(process):
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        assert process.poll() is None, 'Writer exited before copying'
        try:
            state = json.loads((RUNTIME / 'ram-save-operation.json').read_text())
        except (OSError, ValueError):
            state = {}
        if state.get('pid') == process.pid and state.get('copied_bytes', 0) > 0:
            return
        time.sleep(.05)
    raise AssertionError('Writer did not enter frozen copying')


def thawed():
    subprocess.run(['sh', '-c', 'echo thawed > /etc/writeback-thaw; sync -f /etc/writeback-thaw'],
                   check=True, timeout=10)


def main(crash_only=False):
    origin = minios_ram_store.read_origin(str(RUNTIME / 'ram-origin'))
    resolver = minios_ram_store.OriginalStore(origin)
    with resolver.mounted(writable=False) as store:
        before = minios_ram_store.file_manifest(os.path.join(store, '1'))
    Path('/run/writeback-control').mkdir(mode=0o700)
    for action in ('cancel', 'kill'):
        cancel = '/run/writeback-control/cancel'
        Path(cancel).unlink(missing_ok=True)
        with open('/run/writeback-{}.log'.format(action), 'w') as log:
            process = subprocess.Popen([sys.executable, '-B', __file__, 'writer', cancel],
                                       stdout=log, stderr=log, start_new_session=True)
            try:
                wait_copy(process)
                if action == 'cancel':
                    Path(cancel).touch()
                else:
                    os.killpg(process.pid, signal.SIGKILL)
                assert process.wait(timeout=30) != 0
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=10)
            thawed()
        with resolver.mounted(writable=False) as store:
            assert minios_ram_store.file_manifest(os.path.join(store, '1')) == before
        print('FAULT {} PASS'.format(action), flush=True)
    Path(cancel).unlink(missing_ok=True)
    if crash_only:
        with resolver.mounted(writable=False) as store:
            journals = list(Path(store).glob('.ram-save-*'))
            assert journals and all((path / 'prepared').is_file() for path in journals)
            assert minios_ram_store.file_manifest(os.path.join(store, '1')) == before
        print('FAULT boot recovery prepared PASS', flush=True)
        return
    Path('/etc/writeback-fault-result').write_text('saved after faults\n')
    device, plugin = resolver.locate_device()
    assert not plugin
    public = '/run/writeback-public-store'
    Path(public).mkdir(mode=0o700)
    subprocess.run(['mount', '-o', 'rw,nosuid,nodev,noexec', device, public], check=True)
    try:
        status = resolver.status()
        assert status['writable'], status
        subprocess.run(['minios-session', 'save', '1', '--json'], check=True, timeout=90)
        subprocess.run(['mount', '-o', 'remount,ro', public], check=True)
        status = resolver.status()
        assert status['state'] == 'readonly' and not status['writable'], status
        result = subprocess.run(['minios-session', 'save', '1', '--json'],
                                capture_output=True, text=True, timeout=60)
        assert result.returncode != 0 and 'read-only' in result.stdout, result
        subprocess.run(['mount', '-o', 'remount,rw', public], check=True)
    finally:
        subprocess.run(['umount', public], check=True)
    print('FAULT external-mount/readonly PASS', flush=True)
    subprocess.run(['minios-session', 'save', '1', '--json'], check=True, timeout=90)
    with resolver.mounted(writable=True) as store:
        assert not list(Path(store).glob('.ram-save-*'))
        changed = Path(store) / '1/external-change'
        changed.write_text('changed elsewhere\n')
        baseline = minios_ram_store.file_manifest(os.path.join(store, '1'))
    result = subprocess.run(['minios-session', 'save', '1', '--json'],
                            capture_output=True, text=True, timeout=60)
    assert result.returncode != 0 and 'original session changed' in result.stdout, result
    with resolver.mounted(writable=False) as store:
        assert minios_ram_store.file_manifest(os.path.join(store, '1')) == baseline
    result = subprocess.run(['minios-session', 'save', '1', '--as-new', '--json'],
                            capture_output=True, text=True, timeout=90, check=True)
    assert json.loads(result.stdout)['capture']['target_session_id'] == '3', result.stdout
    with resolver.mounted(writable=False) as store:
        assert minios_ram_store.file_manifest(os.path.join(store, '1')) == baseline
        assert (Path(store) / '3/changes.img').is_file()
    print('FAULT conflict/as-new PASS', flush=True)


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'writer':
        writer(sys.argv[2])
    else:
        main(crash_only=len(sys.argv) > 1 and sys.argv[1] == 'crash')
