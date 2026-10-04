"""Recovery preview checks in a disposable installed UEFI QEMU guest only.

Run prepare on the normal root, boot an ordinary entry once to publish EFI
entry IDs, select the snapshot with bootctl, run preview, reboot normally,
then run verify. Artifacts are retained on the normal root under /root.
"""
import argparse
import fcntl
import hashlib
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('phase', choices=('prepare', 'preview', 'verify'))
parser.add_argument('--id')
parser.add_argument('--version')
args = parser.parse_args()
assert subprocess.check_output(['systemd-detect-virt', '--vm'], text=True).strip() in {'qemu', 'kvm'}
assert Path('/sys/firmware/efi').is_dir()
assert json.loads(Path('/etc/titan/install-plan.json').read_text())['bootloader'] == 'limine'


def run(*argv, check=True):
    return subprocess.run(argv, capture_output=True, text=True, check=check)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


marker = Path('/etc/titan-snapshot-acceptance-marker')
state = Path('/root/titan-snapshot-acceptance.json')
excluded = [Path(p) / '.titan-snapshot-acceptance-marker'
            for p in ('/home', '/var/log', '/var/cache/pacman/pkg', '/boot')]
if args.phase == 'prepare':
    assert run('findmnt', '-nro', 'FSROOT', '--mountpoint', '/').stdout.strip() == '/@'
    assert not state.exists() and not marker.exists() and not any(p.exists() for p in excluded)
    menu = Path('/boot/limine.conf')
    baseline = menu.read_bytes()
    lock = Path('/var/lib/pacman/db.lck')
    assert not lock.exists()
    try:
        lock.touch(exist_ok=False)
        refusal = run('titan', 'snapshot', 'create', check=False)
        assert refusal.returncode == 1 and 'package transaction' in refusal.stderr, refusal
        assert menu.read_bytes() == baseline
    finally:
        lock.unlink()
    with Path('/run/titan-snapshot.lock').open('a') as lockfile:
        fcntl.flock(lockfile, fcntl.LOCK_EX | fcntl.LOCK_NB)
        refusal = run('titan', 'snapshot', 'create', check=False)
        assert refusal.returncode == 1 and 'Another snapshot' in refusal.stderr, refusal
        assert menu.read_bytes() == baseline
    print('PASS  transaction and competing snapshot locks refuse without boot mutations', flush=True)
    marker.write_text('snapshot baseline\n')
    for p in excluded:
        p.write_text('separate volume baseline\n')
    created = json.loads(run('titan', 'snapshot', 'create', '--description', 'VM kernel and volatile preview acceptance').stdout)
    assert created['capture_pacman_lock_removed'] is True
    directory = Path('/boot/titan/snapshots') / created['id']
    assert created['kernel']['version'] == run('uname', '-r').stdout.strip()
    assert digest(directory / 'vmlinuz') == created['kernel']['image_sha256']
    assert digest(directory / 'initramfs.img') == created['kernel']['initramfs_sha256']
    assert created in json.loads(run('titan', 'snapshot', 'list', '--json').stdout)['snapshots']
    assert not lock.exists()
    assert not run('findmnt', '-rn', '-o', 'TARGET').stdout.count('/run/titan-snapshot.')
    original = (directory / 'vmlinuz').read_bytes()
    baseline = menu.read_bytes()
    try:
        (directory / 'vmlinuz').write_bytes(original + b'corruption fixture')
        refused = run('titan', 'boot', 'refresh', check=False)
        assert refused.returncode == 1 and 'hash mismatch' in refused.stderr, refused
        assert menu.read_bytes() == baseline
    finally:
        (directory / 'vmlinuz').write_bytes(original)
    run('titan', 'boot', 'refresh')
    marker.write_text('normal root changed after snapshot\n')
    state.write_text(json.dumps(created, indent=2) + '\n')
    print('PASS  matched assets, JSON inventory, lock/mount cleanup and corrupt-image refusal', flush=True)
    print(json.dumps(created), flush=True)
elif args.phase == 'preview':
    assert args.id and args.version
    assert 'systemd.volatile=overlay' in Path('/proc/cmdline').read_text()
    assert 'subvol=@titan-snapshots/' + args.id in Path('/proc/cmdline').read_text()
    assert run('uname', '-r').stdout.strip() == args.version
    assert run('findmnt', '-nro', 'FSTYPE', '--mountpoint', '/').stdout.strip() == 'overlay'
    mounts = json.loads(run('findmnt', '--json', '-o', 'TARGET,FSTYPE,OPTIONS').stdout)

    def flatten(items):
        for item in items:
            yield item
            yield from flatten(item.get('children', []))

    persistent = [item for item in flatten(mounts['filesystems']) if item['fstype'] in ('btrfs', 'vfat')]
    # systemd may detach the lower mount during switch-root; OverlayFS keeps
    # its reference. Any persistent mounts still visible must be read-only.
    assert all('ro' in item['options'].split(',') for item in persistent), persistent
    assert marker.read_text() == 'snapshot baseline\n'
    assert not Path('/var/lib/pacman/db.lck').exists(), 'Capture lock leaked into the snapshot'
    for p in excluded:
        assert run('findmnt', '--mountpoint', str(p.parent), check=False).returncode != 0
        assert not p.exists(), p
        p.write_text('volatile preview write\n')
    marker.write_text('volatile preview root write\n')
    refusal = run('titan', 'boot', 'refresh', check=False)
    assert refusal.returncode == 1 and 'root does not match' in refusal.stderr, refusal
    refusal = run('titan', 'snapshot', 'create', check=False)
    assert refusal.returncode == 1 and 'root does not match' in refusal.stderr, refusal
    print('PASS  historical kernel boots, root overlay writes, persistent mounts read-only, external volumes unmounted', flush=True)
    print('PASS  boot refresh and snapshot create refuse in the preview', flush=True)
else:
    assert run('findmnt', '-nro', 'FSROOT', '--mountpoint', '/').stdout.strip() == '/@'
    assert marker.read_text() == 'normal root changed after snapshot\n'
    assert all(p.read_text() == 'separate volume baseline\n' for p in excluded)
    created = json.loads(state.read_text())
    directory = Path('/boot/titan/snapshots') / created['id']
    assert digest(directory / 'vmlinuz') == created['kernel']['image_sha256']
    assert digest(directory / 'initramfs.img') == created['kernel']['initramfs_sha256']
    marker.unlink()
    for p in excluded:
        p.unlink()
    state.rename(state.with_suffix('.verified.json'))
    print('PASS  normal boot preserves root and all excluded volumes; temporary preview writes disappeared', flush=True)
