"""Real installed-disk boot acceptance; run only inside the disposable QEMU guest."""
import fcntl
import json
import os
import tempfile
from pathlib import Path
import subprocess
import sys

assert subprocess.check_output(['systemd-detect-virt'], text=True).strip() in {'qemu', 'kvm'}
plan = json.loads(Path('/etc/titan/install-plan.json').read_text())
assert plan['bootloader'] == 'limine'
status = subprocess.check_output(['bootctl', 'status', '--no-pager'], text=True)
assert 'Limine' in status, status
menu = Path('/boot/limine.conf')
binary = Path('/boot/EFI/BOOT/BOOTX64.EFI')
header = Path('/etc/titan/limine.conf')
original = {path: path.read_bytes() for path in (menu, binary, header)}
subprocess.run(['titan', 'boot', 'refresh'], check=True)
assert all(path.read_bytes() == data for path, data in original.items())
print('PASS  booted Limine, refresh is repeatable and preserves user header')
with tempfile.TemporaryDirectory(prefix='titan-boot-guard-') as temporary:
    detector = Path(temporary) / 'systemd-detect-virt'
    detector.write_text('#!/bin/sh\necho none\n')
    detector.chmod(0o755)
    result = subprocess.run(['titan', 'boot', 'refresh'], capture_output=True, text=True,
                            env={**os.environ, 'PATH': temporary + ':' + os.environ['PATH']})
    assert result.returncode == 1 and 'QEMU' in result.stderr, result
    assert all(path.read_bytes() == data for path, data in original.items())
print('PASS  physical-machine detection refusal preserves all boot files')
with Path('/run/titan-boot.lock').open('r+') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    result = subprocess.run(['titan', 'boot', 'refresh'], capture_output=True, text=True)
    assert result.returncode == 1 and 'Another boot refresh' in result.stderr, result
    assert all(path.read_bytes() == data for path, data in original.items())
print('PASS  competing refresh is refused without boot-file changes')
try:
    menu.write_bytes(b'# User-managed menu fixture\n')
    result = subprocess.run(['titan', 'boot', 'refresh'], capture_output=True, text=True)
    assert result.returncode == 1 and 'unmanaged' in result.stderr, result
    assert menu.read_bytes() == b'# User-managed menu fixture\n'
    assert binary.read_bytes() == original[binary]
finally:
    menu.write_bytes(original[menu])
print('PASS  unmanaged menu is preserved')
missing = Path('/boot/vmlinuz-linux-zen')
assert not missing.exists() and not missing.is_symlink(), 'Fixture requires an unused kernel path'
try:
    missing.write_bytes(b'incomplete kernel fixture')
    result = subprocess.run(['titan', 'boot', 'refresh'], capture_output=True, text=True)
    assert result.returncode == 1 and 'initramfs' in result.stderr, result
    assert all(path.read_bytes() == data for path, data in original.items())
finally:
    missing.unlink(missing_ok=True)
print('PASS  incomplete kernel update refuses before modifying boot outputs')
try:
    header.write_bytes(original[header].replace(b'interface_branding: Titan', b'interface_branding: Titan acceptance'))
    subprocess.run(['titan', 'boot', 'refresh'], check=True)
    assert b'interface_branding: Titan acceptance' in menu.read_bytes()
    assert menu.with_suffix('.conf.previous').read_bytes() == original[menu]
finally:
    header.write_bytes(original[header])
    subprocess.run(['titan', 'boot', 'refresh'], check=True)
assert menu.read_bytes() == original[menu] and binary.read_bytes() == original[binary]
print('PASS  appearance edits, changed-file backup and restoration')
print(json.dumps(json.loads(subprocess.check_output(['titan', 'boot', 'status', '--json'], text=True)), indent=2))

if '--select-lts' in sys.argv[1:]:
    entries = json.loads(subprocess.check_output(['bootctl', 'list', '--json=short'], text=True))
    entry = next(item['id'] for item in entries if 'linux-lts' in item['id'] and 'fallback' not in item['id'])
    subprocess.run(['bootctl', 'set-oneshot', entry], check=True)
    print('PASS  selected LTS for the next boot:', entry)
