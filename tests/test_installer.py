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
