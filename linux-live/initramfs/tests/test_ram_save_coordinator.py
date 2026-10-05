"""Cross-package save coordination; real freeze is tested separately."""
import contextlib
import hashlib
import json
import os
from pathlib import Path
import sys
from types import SimpleNamespace

import pytest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'submodules/minios-session-manager/lib'))
sys.path.insert(0, str(ROOT / 'submodules/minios-tools/lib'))
import minios_ram_save as tools
import minios_ram_store as store_module
from minios_session import SessionManager


@pytest.fixture
def save_case(tmp_path, monkeypatch):
    ram = tmp_path / 'ram'
    disk = tmp_path / 'disk'
    runtime = tmp_path / 'runtime'
    upper = tmp_path / 'upper'
    for path in (ram, disk, runtime, upper):
        path.mkdir()
    for path in (ram / '1', disk / '1', disk / '2'):
        path.mkdir()
    (ram / '1/changes.img').write_bytes(b'current RAM contents')
    (disk / '1/changes.img').write_bytes(b'original disk contents')
    (disk / '2/changes.img').write_bytes(b'other session')
    metadata = 'default=1\nsession_mode[1]=raw\nsession_state[1]=clean\nsession_mode[2]=raw\n'
    (disk / 'session.conf').write_text(metadata)
    (runtime / 'origin-session.conf').write_text(metadata)
    (ram / 'session.conf').write_text(metadata.replace('clean', 'dirty') + 'running=1\n')
    (runtime / 'boot-id').write_text('test-boot')
    manager = SessionManager(custom_sessions_dir=str(ram))
    manager.custom_sessions_dir = None
    manager.BOOT_STATE_FILE = str(runtime / 'boot-state')
    manager.BOOT_ID_FILE = str(runtime / 'boot-id')
    info = ram.stat()
    boot = {'boot_id': 'test-boot', 'boot_level': 'ok', 'session': '1', 'mode': 'raw',
            'active_generation': 'current',
            'durable': '0', 'writable': '1', 'sessions_device': str(info.st_dev),
            'sessions_inode': str(info.st_ino)}
    origin = {'uuid': 'test-uuid', 'session': '1', 'backend': 'raw',
              'new_session': 'false', 'relative': 'minios/changes'}
    monkeypatch.setattr(store_module, 'read_state', lambda path: dict(boot))
    monkeypatch.setattr(store_module, 'read_origin', lambda path: dict(origin))
    monkeypatch.setattr(store_module, 'read_boot_manifest', lambda path: {
        'changes.img': hashlib.sha256(b'original disk contents').hexdigest()})
    monkeypatch.setattr(store_module, 'read_private_json',
                        lambda path, **kwargs: json.loads(Path(path).read_text()))
    frozen = []
    @contextlib.contextmanager
    def freeze(descriptor, **kwargs):
        frozen.append('freeze')
        try:
            yield
        finally:
            frozen.append('thaw')
    monkeypatch.setattr(tools, 'FrozenFilesystem', freeze)
    class Resolver:
        @contextlib.contextmanager
        def mounted(self, writable=False):
            assert writable
            yield str(disk)
        def command(self, *arguments):
            device = upper.stat().st_dev
            return SimpleNamespace(stdout='ext4 rw {}:{}\n'.format(os.major(device), os.minor(device)))
    saver = store_module.RamSessionSave(manager, tools, Resolver())
    saver.UPPER_PATH = str(upper)
    return SimpleNamespace(saver=saver, ram=ram, disk=disk, runtime=runtime,
                           frozen=frozen, origin=origin, boot=boot)


def test_save_replaces_only_the_selected_session_and_can_repeat(save_case):
    case = save_case
    events = []
    result = case.saver.save('1', progress=events.append)
    assert result['target_session_id'] == '1'
    assert (case.disk / '1/changes.img').read_bytes() == b'current RAM contents'
    assert (case.disk / '2/changes.img').read_bytes() == b'other session'
    assert case.frozen == ['freeze', 'thaw']
    assert events[0] == 'prepare' and events[-1] == 'complete'
    assert any(isinstance(event, dict) and event['copied_bytes'] == event['total_bytes']
               for event in events)
    (case.ram / '1/changes.img').write_bytes(b'next RAM contents')
    case.saver.save('1')
    assert (case.disk / '1/changes.img').read_bytes() == b'next RAM contents'
    assert not list(case.disk.glob('.ram-save-*'))


def test_changed_original_is_not_overwritten(save_case):
    case = save_case
    (case.disk / '1/changes.img').write_bytes(b'changed elsewhere')
    with pytest.raises(store_module.StoreUnavailable, match='original session changed'):
        case.saver.save('1')
    assert case.frozen == []
    assert (case.disk / '1/changes.img').read_bytes() == b'changed elsewhere'
    result = case.saver.save('1', as_new=True)
    assert result['target_session_id'] == '3'
    assert (case.disk / '3/changes.img').read_bytes() == b'current RAM contents'
    assert (case.disk / '1/changes.img').read_bytes() == b'changed elsewhere'


def test_failed_copy_keeps_the_original_and_thaws(save_case, monkeypatch):
    case = save_case
    original = tools.copy_container_file
    def copy(source, target, *args, **kwargs):
        if source == str(case.ram / '1/changes.img'):
            raise OSError('copy failed')
        return original(source, target, *args, **kwargs)
    monkeypatch.setattr(tools, 'copy_container_file', copy)
    with pytest.raises(OSError, match='copy failed'):
        case.saver.save('1')
    assert case.frozen == ['freeze', 'thaw']
    assert (case.disk / '1/changes.img').read_bytes() == b'original disk contents'
    assert not list(case.disk.glob('.ram-save-*'))


def test_runtime_identity_is_checked_before_freezing(save_case):
    case = save_case
    case.boot['sessions_inode'] = '0'
    with pytest.raises(store_module.StoreUnavailable, match='storage changed'):
        case.saver.save('1')
    assert case.frozen == []


def test_stacked_dynfilefs_mount_freezes_only_the_visible_ext4(save_case):
    case = save_case
    command = case.saver.resolver.command
    case.saver.resolver.command = lambda *args: SimpleNamespace(
        stdout='fuse.dynfilefs rw 0:999999\n' + command(*args).stdout)
    case.saver.save('1')
    assert case.frozen == ['freeze', 'thaw']


def test_hidden_ext4_cannot_authorize_freezing_a_different_filesystem(save_case):
    case = save_case
    device = os.stat(case.saver.UPPER_PATH).st_dev
    case.saver.resolver.command = lambda *args: SimpleNamespace(
        stdout='ext4 rw 0:999999\nfuse.dynfilefs rw {}:{}\n'.format(
            os.major(device), os.minor(device)))
    with pytest.raises(store_module.StoreUnavailable, match='writable ext4'):
        case.saver.save('1')
    assert case.frozen == []


def test_squashfs_capture_uses_the_same_transaction_without_freezing(save_case, monkeypatch):
    case = save_case
    case.boot['mode'] = 'squashfs'
    for root in (case.ram, case.disk):
        (root / '1/changes.img').rename(root / '1/changes.sb')
        (root / '1/boot-logs').mkdir()
        (root / '1/boot-logs/log').write_bytes(b'boot trace')
        text = (root / 'session.conf').read_text().replace('session_mode[1]=raw', 'session_mode[1]=squashfs')
        (root / 'session.conf').write_text(text + 'session_generation[1]=5\n')
    (case.runtime / 'origin-session.conf').write_text((case.disk / 'session.conf').read_text())
    monkeypatch.setattr(store_module, 'read_boot_manifest', lambda path: {
        'changes.sb': hashlib.sha256(b'original disk contents').hexdigest(),
        'boot-logs/log': hashlib.sha256(b'boot trace').hexdigest()})
    def capture(output, work, phase, cancel_file=None):
        data = b'hsqs' + b'captured live changes'
        Path(output).write_bytes(data)
        info = os.stat(output)
        return {'sha256': hashlib.sha256(data).hexdigest(), 'compressed_size': len(data),
                'uncompressed_size': 64, 'entry_count': 1, 'extraction_footprint': {},
                'union_backend': 'overlayfs',
                'output_identity': {'device': info.st_dev, 'inode': info.st_ino}}
    monkeypatch.setattr(case.saver.manager, '_run_savechanges', capture)
    case.saver.save('1')
    metadata = json.loads((case.disk / 'session.json').read_text())
    assert metadata['sessions']['1']['generation'] == '6'
    assert (case.disk / '1/changes.sb').read_bytes().startswith(b'hsqs')
    assert (case.disk / '1/boot-logs/log').read_bytes() == b'boot trace'
    assert case.frozen == []
    case.saver.save('1')
    assert json.loads((case.disk / 'session.json').read_text())['sessions']['1']['generation'] == '7'
