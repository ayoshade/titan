"""Real restore/interruption checks, exclusively inside a disposable QEMU VM.

The host harness cold-boots the live ISO between interrupted phases, and then
boots the restored disk with the ISO detached. Fault injection is test-only.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('phase', choices=('prepare', 'interrupt', 'resume-interrupt', 'finish', 'verify'))
parser.add_argument('--id')
args = parser.parse_args()


def run(*argv, check=True, **kwargs):
    result = subprocess.run(argv, check=False, capture_output=True, text=True, **kwargs)
    if check and result.returncode:
        print(result.stderr, file=sys.stderr, flush=True)
        result.check_returncode()
    return result


assert run('systemd-detect-virt', '--vm').stdout.strip() in ('qemu', 'kvm')
assert Path('/sys/firmware/efi').is_dir()
marker = Path('/etc/titan-restore-acceptance')
excluded = [Path(p) / '.titan-restore-acceptance'
            for p in ('/home', '/var/log', '/var/cache/pacman/pkg', '/boot')]

if args.phase == 'prepare':
    assert not Path('/run/archiso/bootmnt').is_mount()
    assert not marker.exists() and not any(p.exists() for p in excluded)
    marker.write_text('captured root\n')
    for p in excluded:
        p.write_text('before capture\n')
    created = json.loads(run('titan', 'snapshot', 'create', '--description', 'Offline restore and interruption acceptance').stdout)
    marker.write_text('broken root after capture\n')
    for p in excluded:
        p.write_text('latest separate volume\n')
    # Remove the only normal kernel and break the greeter after capture. The
    # saved pair and source root must independently recover both later.
    run('pacman', '-R', '--noconfirm', created['kernel']['name'])
    run('systemctl', 'mask', 'greetd')
    Path('/root/titan-restore-acceptance.json').write_text(json.dumps(created) + '\n')
    run('sync')
    print(json.dumps(created), flush=True)
    raise SystemExit()

if args.phase == 'verify':
    assert not Path('/run/archiso/bootmnt').is_mount()
    assert run('findmnt', '-nro', 'FSROOT', '--mountpoint', '/').stdout.strip() == '/@'
    assert marker.read_text() == 'captured root\n'
    assert all(p.read_text() == 'latest separate volume\n' for p in excluded)
    assert run('systemctl', 'is-active', 'greetd').stdout.strip() == 'active'
    with tempfile.TemporaryDirectory(prefix='restore-verify-', dir='/run') as tmp:
        top = Path(tmp)
        run('mount', '-o', 'subvolid=5', '/dev/vda2', tmp)
        try:
            record = json.loads((top / 'titan-restore/journal.json').read_text())
            assert record['phase'] == 'complete'
            old = top / ('@titan-before-' + record['transaction'])
            assert (old / 'etc/titan-restore-acceptance').read_text() == 'broken root after capture\n'
            source = top / ('@titan-snapshots/' + record['snapshot'])
            assert run('btrfs', 'property', 'get', '-ts', str(source), 'ro').stdout.strip() == 'ro=true'
            assert (source / 'etc/titan-restore-acceptance').read_text() == 'captured root\n'
            manifest = json.loads((Path('/boot/titan/snapshots') / record['snapshot'] / 'manifest.json').read_text())
            assert run('uname', '-r').stdout.strip() == manifest['kernel']['version']
            assert not Path('/var/lib/pacman/db.lck').exists()
            for item in record['outputs']:
                target = Path('/boot') / item['path']
                if item['after']:
                    assert hashlib.sha256(target.read_bytes()).hexdigest() == item['after']
                else:
                    assert not target.exists()
                if item['before']:
                    backup = Path('/boot/titan/restores') / record['transaction'] / 'before' / item['path']
                    assert hashlib.sha256(backup.read_bytes()).hexdigest() == item['before']
            Path('/root/titan-restore-verified.json').write_text(json.dumps(record, indent=2) + '\n')
        finally:
            run('umount', tmp)
    run('titan', 'boot', 'refresh')
    print('PASS  ISO-detached restored kernel/root/greeter; latest separate volumes, original root/boot backups and immutable source preserved', flush=True)
    raise SystemExit()

assert Path('/run/archiso/bootmnt').is_mount()
assert args.id
print('Live recovery kernel: ' + run('uname', '-r').stdout.strip(), flush=True)
confirmation = f'RESTORE {args.id} /dev/vda\n'
restore = ['titan', 'snapshot', 'restore', args.id, '--disk', '/dev/vda']
resume = ['titan', 'snapshot', 'restore-resume', '--disk', '/dev/vda']


def status():
    return json.loads(run('titan', 'snapshot', 'restore-status', '--disk', '/dev/vda', '--json').stdout)


def mount_ro():
    top = Path(tempfile.mkdtemp(prefix='restore-check-', dir='/run'))
    esp = Path(tempfile.mkdtemp(prefix='restore-esp-', dir='/run'))
    run('mount', '-o', 'subvolid=5,ro,rescue=nologreplay', '/dev/vda2', str(top))
    run('mount', '-o', 'ro', '/dev/vda1', str(esp))
    return top, esp


def unmount(top, esp):
    run('umount', str(esp)); run('umount', str(top)); top.rmdir(); esp.rmdir()


def interrupt(command, suffix, contains=False):
    with tempfile.TemporaryDirectory(prefix='restore-fault-', dir='/run') as tmp:
        wrapper = Path(tmp) / 'mv'
        wrapper.write_text('''#!/usr/bin/python3
import os,signal,subprocess,sys
result=subprocess.run(['/usr/bin/mv', *sys.argv[1:]])
needle=os.environ['RESTORE_TEST_KILL_DEST']
matched=needle in sys.argv[-1] if os.environ['RESTORE_TEST_MATCH'] == 'contains' else sys.argv[-1].endswith(needle)
if result.returncode == 0 and matched:
 os.sync()
 os.kill(os.getppid(),signal.SIGKILL)
sys.exit(result.returncode)
''')
        wrapper.chmod(0o755)
        result = run(*command, input=confirmation, check=False,
                     env={**os.environ, 'PATH': tmp + ':' + os.environ['PATH'], 'RESTORE_TEST_KILL_DEST': suffix,
                          'RESTORE_TEST_MATCH': 'contains' if contains else 'suffix'})
        assert result.returncode in (137, -9), result
    # A killed restore intentionally leaves mounted recovery paths. This
    # fixture releases them normally; the next phase uses a new live boot.
    table = json.loads(run('findmnt', '-J', '--list', '-o', 'TARGET,SOURCE').stdout)['filesystems']
    owned = [item for item in table if item['target'].startswith('/run/titan-restore.')]
    assert len(owned) == 2, owned
    for item in sorted(owned, key=lambda i: i['target']):
        assert item['source'].split('[')[0] in ('/dev/vda1', '/dev/vda2')
        run('umount', item['target'])


if args.phase == 'interrupt':
    baseline = status(); assert baseline == {'schema': 1, 'restore': None}, baseline
    inventory = json.loads(run('titan', 'snapshot', 'list', '--disk', '/dev/vda', '--json').stdout)
    assert inventory['restore_supported'] is True and any(item['id'] == args.id for item in inventory['snapshots'])
    cancelled = run(*restore, input='CANCEL\n', check=False)
    assert cancelled.returncode == 1 and 'cancelled' in cancelled.stderr, cancelled
    assert status() == baseline
    # Lock contention, target mounts and corrupt saved assets must all refuse.
    with Path('/run/titan-installer/lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        assert run(*restore, input=confirmation, check=False).returncode == 1
    top, esp = mount_ro()
    assert run(*restore, input=confirmation, check=False).returncode == 1
    unmount(top, esp)
    # A mount appearing after inspection but during confirmation must be caught
    # by the second disk check, before any persistent journal or root changes.
    pending = subprocess.Popen(restore, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True)
    prompt = b''; deadline = time.monotonic() + 30
    while b'Type RESTORE ' not in prompt and time.monotonic() < deadline:
        ready, _, _ = select.select([pending.stderr], [], [], 1)
        if ready:
            data = os.read(pending.stderr.fileno(), 8192)
            assert data, prompt
            prompt += data
    assert b'Type RESTORE ' in prompt, prompt
    external = Path(tempfile.mkdtemp(prefix='restore-race-', dir='/run'))
    try:
        run('mount', '-o', 'subvolid=5,ro,rescue=nologreplay', '/dev/vda2', str(external))
        stdout, stderr = pending.communicate(confirmation, timeout=30)
        assert pending.returncode == 1 and 'Disk must be unused' in stderr, (prompt, stderr, stdout)
    finally:
        if external.is_mount():
            run('umount', str(external))
        external.rmdir()
        if pending.poll() is None:
            pending.kill(); pending.wait()
    assert status() == baseline
    esp = Path(tempfile.mkdtemp(prefix='restore-corrupt-', dir='/run'))
    run('mount', '/dev/vda1', str(esp))
    image = esp / 'titan/snapshots' / args.id / 'vmlinuz'
    original = image.read_bytes(); image.write_bytes(original + b'fixture corruption')
    run('umount', str(esp))
    result = run(*restore, input=confirmation, check=False)
    assert result.returncode == 1 and 'hash mismatch' in result.stderr, result
    assert status() == baseline
    run('mount', '/dev/vda1', str(esp)); image.write_bytes(original); run('umount', str(esp)); esp.rmdir()
    print('PASS  cancellation, installer lock, mounted disk, confirmation-time mount and corrupt source refuse without a journal', flush=True)
    # Recovery must also repair a corrupt ordinary menu, while retaining its
    # contents in the boot backup. The recorded source appearance is trusted.
    esp = Path(tempfile.mkdtemp(prefix='restore-menu-', dir='/run'))
    run('mount', '/dev/vda1', str(esp))
    (esp / 'limine.conf').write_text('Broken ordinary menu for restore acceptance\n')
    run('umount', str(esp)); esp.rmdir()
    interrupt(restore, '/@titan-before-', contains=True)
    record = status(); assert record['phase'] == 'staged', record
    top, esp = mount_ro()
    assert not (top / '@').exists()
    assert (top / ('@titan-before-' + record['transaction'])).is_dir()
    assert (top / ('@titan-restore-' + record['transaction'])).is_dir()
    unmount(top, esp)
    print('PASS  SIGKILL between root renames retains both roots and durable staged journal', flush=True)
elif args.phase == 'resume-interrupt':
    record = status(); assert record['phase'] == 'staged', record
    assert run(*restore, input=confirmation, check=False).returncode == 1
    assert run(*resume, input='CANCEL\n', check=False).returncode == 1
    assert status() == record
    interrupt(resume, '/@')
    record = status(); assert record['phase'] == 'root-saved', record
    top, esp = mount_ro()
    assert (top / '@').is_dir() and not (top / ('@titan-restore-' + record['transaction'])).exists()
    unmount(top, esp)
    print('PASS  new live boot resumes missing @; SIGKILL after new-root rename remains resumable', flush=True)
else:
    record = status(); assert record['phase'] == 'root-saved', record
    # Interrupt an atomic boot-file replacement, then resume on this live boot.
    top, esp = mount_ro()
    manifest = json.loads((esp / 'titan/snapshots' / args.id / 'manifest.json').read_text())
    unmount(top, esp)
    interrupt(resume, '/initramfs-' + manifest['kernel']['name'] + '.img')
    assert status()['phase'] == 'root-installed'
    completed = json.loads(run(*resume, input=confirmation).stdout)
    assert completed['phase'] == 'complete' and status() == completed
    assert run(*resume, input=confirmation, check=False).returncode == 1
    print('PASS  interrupted boot publication resumes; completed journal persists and redundant resume refuses', flush=True)
    print(json.dumps(completed), flush=True)
