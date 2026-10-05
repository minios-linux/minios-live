"""Exercise the periodic worker with a due clock in a disposable RAM session."""
from datetime import datetime, timedelta, timezone
import io
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, '/usr/lib/minios-session-manager')
import minios_session
import minios_ram_store

manager = minios_session.SessionManager()
performed, success, message, capture = manager.autosave_running_session()
assert not performed and success, message
Path('/etc/squash-autosave').write_text('periodic contents\n')
real_open = open


def due_uptime(path, *args, **kwargs):
    if path == '/proc/uptime':
        return io.StringIO('3600 0\n')
    return real_open(path, *args, **kwargs)


minios_session.open = due_uptime
performed, success, message, capture = manager.autosave_running_session(
    now=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(minutes=31))
assert performed and success, message
del minios_session.open
origin = minios_ram_store.read_origin('/run/initramfs/minios-persistence/ram-origin')
with minios_ram_store.OriginalStore(origin).mounted(writable=False) as store:
    saved = subprocess.check_output(['unsquashfs', '-cat', store + '/1/changes.sb',
                                     'etc/squash-autosave'], text=True)
    assert saved == 'periodic contents\n', saved
assert manager.autosave_running_session()[0] is False
print('SQUASH periodic PASS', flush=True)
