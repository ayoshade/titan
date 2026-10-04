"""Boot-file refusal and fresh-install selection without privileged host writes."""
import argparse
import os
import subprocess
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lib/titan'))
import install
ROOT = Path(__file__).resolve().parents[1]


class BootSafety(unittest.TestCase):
    def shell(self, script, *args):
        return subprocess.run(['bash', '-c', 'set -euo pipefail; source "$1/lib/titan/boot.sh"; ' + script,
                               'test', str(ROOT), *map(str, args)], capture_output=True, text=True)

    def test_nonroot_refresh_refuses_without_touching_boot_files(self):
        if os.geteuid() == 0:
            self.skipTest('Nonroot refusal requires ordinary test runner')
        result = subprocess.run([str(ROOT / 'scripts/titan-boot'), 'refresh'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('requires root', result.stderr)

    def test_nonroot_snapshot_capture_and_invalid_routes_refuse(self):
        if os.geteuid() == 0:
            self.skipTest('Nonroot refusal requires ordinary test runner')
        result = subprocess.run([str(ROOT / 'bin/titan'), 'snapshot', 'create'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('requires root', result.stderr)
        for arguments in [('snapshot', 'restore', '1'), ('service', 'setup', '--arbitrary-unit'),
                          ('service', 'receive', 'docker', '/tmp')]:
            result = subprocess.run([str(ROOT / 'bin/titan'), *arguments], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2, result.stderr)

    def test_incomplete_kernel_and_linked_paths_refuse(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'vmlinuz-linux').write_bytes(b'kernel')
            config = root / 'header'; config.write_text('timeout: 3\n')
            uuid = '12345678-1234-1234-1234-123456789012'
            result = self.shell('titan_boot_render "$2" "$3" "$4"', uuid, root, config)
            self.assertEqual(result.returncode, 1)
            self.assertIn('initramfs', result.stderr)
            (root / 'initramfs-linux.img').write_bytes(b'initramfs')
            self.assertEqual(self.shell('titan_boot_render "$2" "$3" "$4"', uuid, root, config).returncode, 0)
            output = root / 'linked'; output.symlink_to(config)
            self.assertEqual(self.shell('titan_boot_path "$2"', output).returncode, 1)
            self.assertEqual(config.read_text(), 'timeout: 3\n')
            directory = root / 'dir'; directory.symlink_to(root, target_is_directory=True)
            self.assertEqual(self.shell('titan_boot_path "$2"', directory / 'other').returncode, 1)
            self.assertFalse((root / 'other').exists())

    def test_uuid_injection_is_refused(self):
        result = self.shell('titan_boot_render "$2" /unused /unused', 'uuid\n/foreign')
        self.assertEqual(result.returncode, 1)
        self.assertIn('UUID', result.stderr)

    def test_bootloader_plan_selection_adds_only_requested_dependency(self):
        args = argparse.Namespace(user='tester', hostname='titan', timezone='UTC', disk='/dev/vda', vm_repo=None)
        with patch.object(install, 'check_disk', return_value={'name': '/dev/vda', 'size': 40 * 1024**3, 'model': 'QEMU'}), patch.object(install, 'detect', return_value={'packages': []}):
            default = install.plan(args)
            args.bootloader = 'limine'
            limine = install.plan(args)
            self.assertEqual(default['bootloader'], 'systemd-boot')
            self.assertNotIn('limine', default['packages'])
            self.assertIn('limine', limine['packages'])
            args.bootloader = 'unknown'
            with self.assertRaisesRegex(ValueError, 'bootloader'):
                install.plan(args)
