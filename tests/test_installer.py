"""Safety boundaries and package selection, without privileged operations."""
import argparse
import copy
from pathlib import Path
import sys
import tempfile
import unittest
import os
import shutil
import subprocess
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib/titan"))
import hardware
import install


class DiskSafety(unittest.TestCase):
    def setUp(self):
        self.disk = {"name": "/dev/vda", "type": "disk", "size": 40 * 1024**3,
                     "ro": False, "model": "QEMU", "mountpoints": [None]}

    def test_blank_whole_disk_is_eligible(self):
        self.assertEqual(install.check_disk("/dev/vda", [self.disk]), self.disk)

    def test_partition_is_never_a_whole_disk(self):
        self.disk["children"] = [{"name": "/dev/vda1", "type": "part"}]
        with self.assertRaisesRegex(ValueError, "whole disk"):
            install.check_disk("/dev/vda1", [self.disk])

    def test_nested_mount_and_swap_are_rejected(self):
        for mount in ["/", "/home", "/run/archiso/bootmnt", "[SWAP]"]:
            with self.subTest(mount=mount):
                disk = copy.deepcopy(self.disk)
                disk["children"] = [{"name": "/dev/vda1", "mountpoints": [None], "children": [
                    {"name": "/dev/mapper/data", "mountpoints": [mount]}]}]
                with self.assertRaisesRegex(ValueError, "in use"):
                    install.check_disk("/dev/vda", [disk])

    def test_readonly_small_and_loop_targets_are_rejected(self):
        for field, value in [("ro", True), ("size", 16 * 1024**3), ("type", "loop")]:
            with self.subTest(field=field):
                disk = dict(self.disk, **{field: value})
                with self.assertRaises(ValueError):
                    install.check_disk("/dev/vda", [disk])

    def test_unmounted_disk_with_storage_holders_is_rejected(self):
        with patch.object(install.Path, "exists", return_value=True), \
                patch.object(install.Path, "iterdir", return_value=iter([Path("/dev/dm-0")])):
            with self.assertRaisesRegex(ValueError, "holders"):
                install.check_disk("/dev/vda", [self.disk])

    def test_apply_outside_live_environment_never_runs_a_command(self):
        with patch.object(install.os, "geteuid", return_value=1000), patch.object(install, "run") as run:
            with self.assertRaisesRegex(ValueError, "live ISO"):
                install.apply(argparse.Namespace(), {})
            run.assert_not_called()

    def test_real_machine_apply_is_rejected_before_writes(self):
        with patch.object(install.os, "geteuid", return_value=0), \
                patch.object(install.Path, "is_mount", return_value=True), \
                patch.object(install, "run", return_value="none\n") as run:
            with self.assertRaisesRegex(ValueError, "only in QEMU"):
                install.apply(argparse.Namespace(), {})
            run.assert_called_once_with("systemd-detect-virt", capture=True)

    def test_development_repository_must_be_qemu_host_url(self):
        with patch.object(install.os, "geteuid", return_value=0), \
                patch.object(install.Path, "is_mount", return_value=True), \
                patch.object(install.Path, "is_dir", return_value=True), \
                patch.object(install, "run", return_value="kvm\n") as run:
            with self.assertRaisesRegex(ValueError, "QEMU's host"):
                install.apply(argparse.Namespace(vm_repo="http://example.com/repo"),
                              {"hardware": {"installer_supported": True}})
            run.assert_called_once_with("systemd-detect-virt", capture=True)

    def test_account_and_hostname_injection_are_rejected_before_disk_inspection(self):
        valid = dict(user="titan", hostname="titan", timezone="UTC", disk="/dev/vda", vm_repo=None)
        for values in [dict(user="root"), dict(user="greeter"), dict(user="bad\nname"),
                       dict(hostname="bad;command"), dict(timezone="../etc/passwd")]:
            with self.subTest(values=values), patch.object(install, "block_devices") as disks:
                with self.assertRaises(ValueError):
                    install.plan(argparse.Namespace(**(valid | values)))
                disks.assert_not_called()


class InstallerRecovery(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        base = Path(self.directory.name)
        self.target = base / "target"
        self.target.mkdir()
        self.state = base / "state"
        self.state.mkdir()
        for name, value in [("TARGET", self.target), ("STATE", self.state)]:
            patcher = patch.object(install, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.disk = "/dev/titan-test-disk"
        self.identities = {self.disk: os.makedev(252, 0), self.disk + "1": os.makedev(252, 1),
                           self.disk + "2": os.makedev(252, 2)}
        real_stat = os.stat
        def device_stat(path, *args, **kwargs):
            if str(path) in self.identities:
                return SimpleNamespace(st_rdev=self.identities[str(path)])
            return real_stat(path, *args, **kwargs)
        patcher = patch.object(install.os, "stat", side_effect=device_stat)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.devices = [{"name": self.disk, "size": 40 * 1024**3, "type": "disk", "ro": False,
                         "mountpoints": [None], "children": [
                             {"name": self.disk + "2", "mountpoints": [str(self.target)]}]}]
        patcher = patch.object(install, "block_devices", return_value=self.devices)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.mounts = [{"target": str(self.target), "maj:min": "0:29",
                        "source": self.disk + "2[/@]", "uuid": "root-uuid", "fsroot": "/@"}]
        self.uuid = "root-uuid"
        def command(*args, **kwargs):
            if args[0] == "findmnt":
                return install.json.dumps({"filesystems": self.mounts})
            if args[0] == "blkid":
                return self.uuid + "\n"
            if args[0] == "umount":
                self.mounts.clear()
                self.devices[0]["children"][0]["mountpoints"] = [None]
                return ""
            raise AssertionError(args)
        patcher = patch.object(install, "run", side_effect=command)
        self.run = patcher.start()
        self.addCleanup(patcher.stop)
        self.record = {"schema": 1, "target": str(self.target), "status": "failed",
                       "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
                       "step": "base-packages", "disk": {"name": self.disk,
                       "size": 40 * 1024**3, "identity": self.identities[self.disk]},
                       "mounts": [{"target": str(self.target), "device": self.disk + "2",
                                   "maj:min": "252:2", "uuid": self.uuid, "fsroot": "/@"}]}
        install.checkpoint(self.record)

    def test_status_is_readonly_and_reports_live_mounts(self):
        before = (self.state / "attempt.json").read_bytes()
        result = install.status()
        self.assertEqual(result["attempt"]["step"], "base-packages")
        self.assertEqual(result["live_mounts"], self.mounts)
        self.assertEqual((self.state / "attempt.json").read_bytes(), before)
        self.assertFalse((self.state / "lock").exists())

    def test_foreign_nested_mount_is_never_unmounted(self):
        self.mounts.append({"target": str(self.target / "boot"), "maj:min": "0:99"})
        with self.assertRaisesRegex(ValueError, "foreign"):
            install.release_target(self.record)
        self.assertFalse(any(call.args[0] == "umount" for call in self.run.call_args_list))

    def test_changed_filesystem_device_and_boot_are_rejected(self):
        for change in ["uuid", "device", "boot"]:
            with self.subTest(change=change):
                record = copy.deepcopy(self.record)
                self.uuid = "changed" if change == "uuid" else "root-uuid"
                self.identities[self.disk] = os.makedev(252, 9 if change == "device" else 0)
                if change == "boot":
                    record["boot_id"] = "another-boot"
                with self.assertRaises(ValueError):
                    install.release_target(record)
        self.assertFalse(any(call.args[0] == "umount" for call in self.run.call_args_list))

    def test_same_filesystem_wrong_subvolume_is_refused(self):
        self.mounts[0]["fsroot"] = "/@home"
        with self.assertRaisesRegex(ValueError, "foreign"):
            install.release_target(self.record)
        self.assertFalse(any(call.args[0] == "umount" for call in self.run.call_args_list))

    def test_disk_use_outside_target_and_swap_are_rejected(self):
        for mount in ["/mnt/other", "[SWAP]"]:
            with self.subTest(mount=mount):
                self.devices[0]["children"][0]["mountpoints"] = [mount]
                with self.assertRaisesRegex(ValueError, "outside"):
                    install.release_target(self.record)
        self.assertFalse(any(call.args[0] == "umount" for call in self.run.call_args_list))

    def test_busy_unmount_preserves_marker_and_journal(self):
        command = self.run.side_effect
        def busy(*args, **kwargs):
            if args[0] == "umount":
                raise subprocess.CalledProcessError(32, list(args))
            return command(*args, **kwargs)
        self.run.side_effect = busy
        with self.assertRaises(subprocess.CalledProcessError):
            install.release_target(self.record)
        self.assertTrue(self.target.exists())
        self.assertEqual(install.read_attempt()["status"], "failed")

    def test_recovery_unmounts_without_erasing_and_requires_exact_confirmation(self):
        with patch.object(install, "require_live_vm"), patch.object(install.os, "isatty", return_value=True), \
                patch("builtins.input", return_value="RECOVER " + self.disk):
            install.recover(argparse.Namespace(disk=self.disk))
        self.assertFalse(self.target.exists())
        self.assertEqual(install.read_attempt()["status"], "recovered")
        self.assertEqual([call.args[0] for call in self.run.call_args_list if call.args[0] != "findmnt"],
                         ["blkid", "blkid", "umount"])

    def test_cancellation_and_wrong_disk_preserve_everything(self):
        with patch.object(install, "require_live_vm"), patch.object(install.os, "isatty", return_value=True), \
                patch("builtins.input", return_value="yes"):
            with self.assertRaisesRegex(ValueError, "cancelled"):
                install.recover(argparse.Namespace(disk=self.disk))
            with self.assertRaisesRegex(ValueError, "matching"):
                install.recover(argparse.Namespace(disk="/dev/another-disk"))
        self.assertTrue(self.target.exists())
        self.assertEqual(install.read_attempt()["status"], "failed")

    def test_foreign_mount_appearing_during_confirmation_is_rejected(self):
        def confirm(prompt):
            self.mounts.append({"target": str(self.target / "boot"), "source": "tmpfs",
                                "maj:min": "0:99", "uuid": None, "fsroot": "/"})
            return "RECOVER " + self.disk
        with patch.object(install, "require_live_vm"), patch.object(install.os, "isatty", return_value=True), \
                patch("builtins.input", side_effect=confirm):
            with self.assertRaisesRegex(ValueError, "foreign"):
                install.recover(argparse.Namespace(disk=self.disk))
        self.assertFalse(any(call.args[0] == "umount" for call in self.run.call_args_list))

    def test_recovery_outside_live_environment_does_not_mutate_state(self):
        before = (self.state / "attempt.json").read_bytes()
        with patch.object(install.os, "geteuid", return_value=1000):
            with self.assertRaisesRegex(ValueError, "live ISO"):
                install.recover(argparse.Namespace(disk=self.disk))
        self.run.assert_not_called()
        self.assertEqual((self.state / "attempt.json").read_bytes(), before)
        self.assertFalse((self.state / "lock").exists())

    def test_json_and_conflicting_mutations_are_rejected_by_cli(self):
        cli = Path(__file__).resolve().parents[1] / "scripts/titan-install"
        for arguments in [("--json", "--apply"), ("--json", "--recover"), ("--apply", "--recover")]:
            with self.subTest(arguments=arguments):
                result = subprocess.run([str(cli), *arguments], text=True, capture_output=True)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, "")

    def test_nonempty_retry_directory_is_never_deleted(self):
        sentinel = self.target / "keep-me"
        sentinel.write_text("partial data")
        with self.assertRaises(OSError):
            install.release_target(self.record)
        self.assertEqual(sentinel.read_text(), "partial data")

    def test_concurrent_worker_keeps_operation_locked_after_parent_closes(self):
        # A subprocess holding the inherited fd protects recovery even if its
        # installer parent exits. No privileged mount/device operation occurs.
        with install.operation_lock():
            self.assertTrue(install.status()["busy"])
            child = subprocess.Popen([sys.executable, "-c", "import sys,time; print('ready',flush=True); time.sleep(30)"],
                                     pass_fds=(install.LOCK_FD,), stdout=subprocess.PIPE, text=True)
            self.assertEqual(child.stdout.readline().strip(), "ready")
        try:
            with self.assertRaisesRegex(ValueError, "still running"):
                with install.operation_lock():
                    self.fail("Lock was lost while a worker remained alive")
        finally:
            child.terminate()
            child.wait(timeout=5)
            child.stdout.close()
        with install.operation_lock():
            pass

    def test_corrupt_journal_refuses_recovery(self):
        (self.state / "attempt.json").write_text('{"schema":1}')
        with self.assertRaisesRegex(ValueError, "Invalid"):
            install.read_attempt()

    def test_journal_write_failure_does_not_mask_install_failure(self):
        with patch.object(install, "checkpoint", side_effect=OSError("state full")), \
                patch.object(install.sys, "stderr"):
            install.failure_checkpoint(self.record, status="failed")


class HardwareProfiles(unittest.TestCase):
    def test_vendor_packages_and_nvidia_boundary(self):
        for vendor, expected, supported in [("0x8086", "vulkan-intel", True),
                ("0x1002", "vulkan-radeon", True), ("0x1234", None, True),
                ("0x10de", None, False), ("0xffff", None, False)]:
            with self.subTest(vendor=vendor), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                (root / "proc").mkdir()
                (root / "proc/cpuinfo").write_text("vendor_id : AuthenticAMD\n")
                device = root / "sys/bus/pci/devices/0000:00:02.0"
                device.mkdir(parents=True)
                (device / "class").write_text("0x030000\n")
                (device / "vendor").write_text(vendor)
                (device / "device").write_text("0x0001")
                battery = root / "sys/class/power_supply/BAT1"
                battery.mkdir(parents=True)
                (battery / "type").write_text("Battery")
                result = hardware.detect(root)
                self.assertIn("amd-ucode", result["packages"])
                self.assertNotIn("intel-ucode", result["packages"])
                self.assertTrue(result["laptop"])
                self.assertEqual(result["installer_supported"], supported)
                if expected:
                    self.assertIn(expected, result["packages"])


class FirstLogin(unittest.TestCase):
    def test_session_log_alone_does_not_run_existing_user_migration(self):
        source = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / "source"
            home = Path(folder) / "home"
            (root / "scripts").mkdir(parents=True)
            for path in ["scripts/titan", "scripts/install-agent-skills", "version"]:
                shutil.copy(source / path, root / path)
            for path in ["migrations", "default", "config/gtk-3.0", "config/gtk-4.0"]:
                shutil.copytree(source / path, root / path)
            # Prevent theme application, process signals, D-Bus or service
            # changes on this host. The real setup/migration code is exercised.
            theme = root / "scripts/apply-theme"
            theme.write_text("#!/bin/sh\nexit 0\n")
            theme.chmod(0o755)
            binaries = Path(folder) / "bin"
            binaries.mkdir()
            for name in ["gsettings", "systemctl"]:
                tool = binaries / name
                tool.write_text("#!/bin/sh\nexit 0\n")
                tool.chmod(0o755)
            state = home / ".local/state/titan"
            state.mkdir(parents=True)
            (state / "setup.log").write_text("")
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
                       XDG_STATE_HOME=str(home / ".local/state"), CODEX_HOME=str(home / ".codex"),
                       PATH=str(binaries) + ":" + os.environ["PATH"])
            subprocess.run([str(root / "scripts/titan"), "setup"], env=env, check=True, capture_output=True)
            self.assertTrue((state / "setup-version").is_file())
            self.assertFalse((state / "welcome-done").exists())
            self.assertEqual(len(list((state / "migrations").glob("*.sh"))), len(list((root / "migrations").glob("*.sh"))))
            override = home / ".config/titan/hypr.lua"
            override.write_text("-- user's override\n")
            subprocess.run([str(root / "scripts/titan"), "setup"], env=env, check=True, capture_output=True)
            self.assertEqual(override.read_text(), "-- user's override\n")
            self.assertFalse((state / "welcome-done").exists())


if __name__ == "__main__":
    unittest.main()
