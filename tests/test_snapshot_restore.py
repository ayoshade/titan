"""Offline restore refusal and interrupted transitions without host disk writes."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ID = '20261004T120000Z-Ab1234'
TXN = ID + '-1234abcd'
UUID = '12345678-1234-1234-1234-123456789012'


class SnapshotRestore(unittest.TestCase):
    def shell(self, code, directory):
        return subprocess.run(['bash', '-c', '''set -euo pipefail
source "$1/lib/titan/boot.sh"
source "$1/lib/titan/snapshot_restore.sh"
restore_top=$2/root; restore_esp=$2/esp
restore_uuid=12345678-1234-1234-1234-123456789012
restore_esp_uuid=1234-ABCD; restore_identity=fixture
restore_journal=$restore_top/titan-restore/journal.json
''' + code, 'test', str(ROOT), str(directory)], capture_output=True, text=True)

    def record(self):
        return dict(schema=1, snapshot=ID, transaction=TXN, root_uuid=UUID,
                    esp_uuid='1234-ABCD', disk_identity='fixture', old_id=300,
                    source_id=301, new_id=302, phase='staged',
                    outputs=[dict(path='limine.conf', before=None, after=None),
                             dict(path='EFI/BOOT/BOOTX64.EFI', before=None, after=None)])

    def fixture(self, directory, record):
        journal = directory / 'root/titan-restore/journal.json'
        journal.parent.mkdir(parents=True, exist_ok=True)
        journal.write_text(json.dumps(record))
        (directory / 'esp').mkdir(exist_ok=True)

    def test_live_root_and_argument_boundaries(self):
        if os.geteuid() == 0:
            self.skipTest('Ordinary host runner required')
        for action in [('list', '--disk', '/dev/vda', '--json'), ('restore', ID, '--disk', '/dev/vda'),
                       ('restore-status', '--disk', '/dev/vda'),
                       ('restore-resume', '--disk', '/dev/vda')]:
            result = subprocess.run([str(ROOT / 'bin/titan'), 'snapshot', *action], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result)
            self.assertIn('requires root', result.stderr)
        for action in [('restore', '../foreign', '--disk', '/dev/vda'),
                       ('restore', ID, '--disk', '/dev/vda', '--yes'),
                       ('restore-resume', '--disk', '/dev/vda', '--json')]:
            result = subprocess.run([str(ROOT / 'bin/titan'), 'snapshot', *action], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2, result)

    def test_journal_corruption_and_changed_identity_refuse(self):
        mutations = [dict(root_uuid='different'), dict(esp_uuid='FFFF-FFFF'),
                     dict(disk_identity='changed'), dict(transaction='../foreign'),
                     dict(snapshot='../foreign'), dict(old_id=5), dict(new_id=None),
                     dict(new_id=300), dict(phase='guess'),
                     dict(outputs=[dict(path='../foreign', before=None, after=None)]),
                     dict(outputs=[dict(path='limine.conf', before=None, after=None)] * 2)]
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            for mutation in mutations:
                record = self.record(); record.update(mutation)
                self.fixture(directory, record)
                result = self.shell('titan_restore_read', directory)
                self.assertEqual(result.returncode, 1, (mutation, result))
                self.assertEqual(json.loads((directory / 'root/titan-restore/journal.json').read_text()), record)
            self.fixture(directory, self.record())
            self.assertEqual(self.shell('titan_restore_read', directory).returncode, 0)

    def test_fstab_must_keep_separate_volumes_and_select_root_by_name(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            source = directory / 'root/@titan-snapshots' / ID
            assets = directory / 'esp/titan/snapshots' / ID
            assets.mkdir(parents=True)
            subvolumes = {'@': '/', '@home': '/home', '@log': '/var/log', '@pkg': '/var/cache/pacman/pkg'}
            plan = dict(schema=1, root_uuid=UUID, bootloader='limine', apply_scope='QEMU live VM only',
                        filesystem='btrfs', encryption=False, subvolumes=subvolumes)
            files = {'etc/titan/install-plan.json': json.dumps(plan),
                     'etc/titan/limine.conf': 'timeout: 3\n', 'usr/share/limine/BOOTX64.EFI': 'firmware',
                     'usr/lib/modules/7.2.8/vmlinuz': 'kernel', 'usr/lib/modules/7.2.8/pkgbase': 'linux'}
            for relative, contents in files.items():
                path = source / relative; path.parent.mkdir(parents=True, exist_ok=True); path.write_text(contents)
            for name, contents in [('vmlinuz', b'kernel'), ('initramfs.img', b'initramfs')]:
                (assets / name).write_bytes(contents)
            manifest = dict(schema=1, id=ID, root_uuid=UUID, subvolume='@titan-snapshots/' + ID,
                            description='fixture', created='2026-10-04', kernel=dict(name='linux', version='7.2.8',
                            image_sha256=hashlib.sha256(b'kernel').hexdigest(),
                            initramfs_sha256=hashlib.sha256(b'initramfs').hexdigest()))
            (assets / 'manifest.json').write_text(json.dumps(manifest))
            baseline = ''.join(f'UUID={UUID} {target} btrfs rw,subvol=/{subvolume} 0 0\n'
                               for subvolume, target in subvolumes.items()) + 'UUID=1234-ABCD /boot vfat rw 0 2\n'
            code = '''btrfs() { printf 'ro=true\\n'; }
titan_restore_subid() { printf '301\\n'; }
titan_restore_source ''' + ID
            fstab = source / 'etc/fstab'
            fstab.write_text(baseline)
            result = self.shell(code, directory)
            self.assertEqual(result.returncode, 0, result.stderr)
            for altered in [baseline.replace('subvol=/@home', 'subvol=/@'),
                            baseline.replace('rw,subvol=/@ ', 'rw,subvolid=300,subvol=/@ '),
                            baseline.replace('UUID=1234-ABCD', 'UUID=FFFF-FFFF')]:
                fstab.write_text(altered)
                result = self.shell(code, directory)
                self.assertEqual(result.returncode, 1, result)
                self.assertIn('fstab', result.stderr)

    def transition_fixture(self, directory, phase):
        record = self.record(); record['phase'] = phase
        old = directory / ('root/@' if phase == 'staged' else 'root/@titan-before-' + TXN)
        new = directory / ('root/@titan-restore-' + TXN if phase in ('staged', 'root-saved') else 'root/@')
        for path, identity in [(old, '300'), (new, '302')]:
            path.mkdir(parents=True); (path / '.identity').write_text(identity)
        stage = directory / ('esp/titan/restores/' + TXN)
        for version, content in [('before', b'original'), ('new', b'restored')]:
            for relative in ['limine.conf', 'EFI/BOOT/BOOTX64.EFI']:
                target = stage / version / relative
                target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(content)
        for output in record['outputs']:
            output['before'] = hashlib.sha256(b'original').hexdigest()
            output['after'] = hashlib.sha256(b'restored').hexdigest()
            target = directory / 'esp' / output['path']
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b'restored' if phase == 'boot-installed' else b'original')
        self.fixture(directory, record)

    APPLY = '''titan_restore_read
titan_restore_owned_mounts() { :; }
titan_restore_subid() { cat "$1/.identity"; }
titan_restore_apply'''

    def test_resume_each_root_and_boot_transition_retains_original(self):
        for phase in ('staged', 'root-saved', 'root-installed', 'boot-installed'):
            with self.subTest(phase=phase), tempfile.TemporaryDirectory() as tmp:
                directory = Path(tmp); self.transition_fixture(directory, phase)
                result = self.shell(self.APPLY, directory)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout)['phase'], 'complete')
                self.assertEqual((directory / 'root/@/.identity').read_text(), '302')
                self.assertEqual((directory / ('root/@titan-before-' + TXN) / '.identity').read_text(), '300')
                self.assertEqual((directory / 'esp/limine.conf').read_bytes(), b'restored')
                self.assertEqual((directory / ('esp/titan/restores/' + TXN) / 'before/limine.conf').read_bytes(), b'original')

    def test_tampered_staging_backup_or_destination_refuses_before_root_rename(self):
        for relative in ['esp/titan/restores/' + TXN + '/new/limine.conf',
                         'esp/titan/restores/' + TXN + '/before/limine.conf', 'esp/limine.conf']:
            with self.subTest(path=relative), tempfile.TemporaryDirectory() as tmp:
                directory = Path(tmp); self.transition_fixture(directory, 'staged')
                (directory / relative).write_bytes(b'foreign')
                result = self.shell(self.APPLY, directory)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((directory / 'root/@/.identity').read_text(), '300')
                self.assertFalse((directory / ('root/@titan-before-' + TXN)).exists())

    def test_symlinked_journal_and_staged_files_refuse(self):
        for phase in ('staged', 'preparing'):
            with self.subTest(phase=phase), tempfile.TemporaryDirectory() as tmp:
                directory = Path(tmp); self.transition_fixture(directory, 'staged')
                journal = directory / 'root/titan-restore/journal.json'
                if phase == 'preparing':
                    record = json.loads(journal.read_text()); record.update(phase=phase, new_id=None)
                    journal.write_text(json.dumps(record))
                    manifest = directory / 'esp/titan/snapshots' / ID / 'manifest.json'
                    manifest.parent.mkdir(parents=True)
                    manifest.write_text(json.dumps({'kernel': {'name': 'linux'}}))
                target = directory / 'foreign'; target.write_bytes(b'private')
                stage = directory / ('esp/titan/restores/' + TXN) / 'new/limine.conf'
                stage.unlink(); stage.symlink_to(target)
                self.assertNotEqual(self.shell(self.APPLY, directory).returncode, 0)
                self.assertEqual(target.read_bytes(), b'private')
                self.assertEqual((directory / 'root/@/.identity').read_text(), '300')
                journal.unlink(); journal.symlink_to(target)
                self.assertNotEqual(self.shell('titan_restore_read', directory).returncode, 0)
                self.assertEqual(target.read_bytes(), b'private')
