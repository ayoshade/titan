"""Fault injection confined to the harness's disposable UEFI live QEMU VM."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

from vm_install_driver import drive, install_command, install_prompts


def command(*args):
    return subprocess.run(args, text=True, check=True, capture_output=True).stdout


def status():
    return json.loads(command("titan-install", "--status", "--json"))


def refused(*args, message):
    result = subprocess.run(["titan-install", *args], text=True, capture_output=True)
    assert result.returncode == 1 and message in result.stderr, result.stderr


def check_recovery(repository):
    sys.path.insert(0, "/usr/share/titan-installer/lib/titan")
    import install
    install.require_live_vm()
    assert status()["attempt"] is None, "Need a fresh disposable live VM"
    with tempfile.TemporaryDirectory(prefix="titan-recovery-fixture-") as folder:
        wrapper = Path(folder) / "pacstrap"
        worker_file = Path(folder) / "worker.pid"
        wrapper.write_text("#!/bin/sh\nexit 72\n")
        wrapper.chmod(0o755)
        code = drive(install_command(repository), install_prompts(),
                     env=dict(os.environ, PATH=folder + ":" + os.environ["PATH"]), timeout=120)
        failed = status()
        assert code == 1 and failed["attempt"]["status"] == "failed"
        assert failed["attempt"]["step"] == "base-packages" and failed["attempt"]["exit_code"] == 72
        assert not failed["live_mounts"] and failed["target_exists"]
        assert "titanvm" not in json.dumps(failed), "Password leaked into recovery state"
        assert drive(["titan-install", "--recover", "--disk", "/dev/vda"],
                     [(b"Type RECOVER /dev/vda to continue:", b"RECOVER /dev/vda\n")], timeout=30) == 0
        print("PASS  Failed package step records failure, unmounts and supports confirmed retry", flush=True)
        wrapper.write_text("#!/usr/bin/python3\nimport os,signal,time\n"
                           f"open({str(worker_file)!r},'w').write(str(os.getpid()))\n"
                           "signal.signal(signal.SIGHUP,signal.SIG_IGN)\n"
                           "os.kill(os.getppid(),signal.SIGKILL)\n"
                           "print('RECOVERY_FAULT_READY',flush=True)\ntime.sleep(120)\n")
        wrapper.chmod(0o755)
        checked_worker = False
        worker_output = b""
        def worker_check(data):
            nonlocal checked_worker, worker_output
            worker_output = (worker_output + data)[-4096:]
            if checked_worker or b"RECOVERY_FAULT_READY" not in worker_output:
                return
            interrupted = status()
            assert interrupted["busy"] and len(interrupted["live_mounts"]) == 5, interrupted
            refused("--recover", "--disk", "/dev/vda", message="still running")
            checked_worker = True
            worker = int(worker_file.read_text())
            assert str(wrapper).encode() in Path(f"/proc/{worker}/cmdline").read_bytes()
            os.kill(worker, signal.SIGTERM)
        try:
            code = drive(install_command(repository), install_prompts(),
                         env=dict(os.environ, PATH=folder + ":" + os.environ["PATH"]),
                         on_data=worker_check, timeout=120)
            assert code == -signal.SIGKILL and checked_worker, code
        finally:
            if worker_file.exists():
                worker = int(worker_file.read_text())
                try:
                    if str(wrapper).encode() in Path(f"/proc/{worker}/cmdline").read_bytes():
                        os.kill(worker, signal.SIGTERM)
                except FileNotFoundError:
                    pass
    for _ in range(50):
        if not status()["busy"]:
            break
        time.sleep(.1)
    interrupted = status()
    assert not interrupted["busy"] and interrupted["attempt"]["step"] == "base-packages"
    assert len(interrupted["live_mounts"]) == 5
    print("PASS  Killed installer retains checkpoint/mounts; surviving worker blocks recovery", flush=True)
    # A same-path foreign mount must not be swallowed by recursive unmount.
    command("mount", "-t", "tmpfs", "tmpfs", "/mnt/titan-target/boot")
    try:
        result = drive(["titan-install", "--recover", "--disk", "/dev/vda"], [], timeout=30)
        assert result == 1 and len(status()["live_mounts"]) == 6
    finally:
        command("umount", "/mnt/titan-target/boot")
    print("PASS  Foreign mount is refused and retained", flush=True)
    # An open working directory makes the actual kernel unmount fail.
    holder = subprocess.Popen(["sleep", "120"], cwd="/mnt/titan-target")
    try:
        result = drive(["titan-install", "--recover", "--disk", "/dev/vda"],
                       [(b"Type RECOVER /dev/vda to continue:", b"RECOVER /dev/vda\n")], timeout=30)
        assert result == 1 and status()["target_exists"]
        assert status()["attempt"]["status"] == "running"
    finally:
        holder.terminate()
        holder.wait(timeout=5)
    print("PASS  Busy mount refuses cleanup and keeps recovery marker", flush=True)
    result = drive(["titan-install", "--recover", "--disk", "/dev/vda"],
                   [(b"Type RECOVER /dev/vda to continue:", b"cancel\n")], timeout=30)
    assert result == 1 and status()["target_exists"]
    assert drive(["titan-install", "--recover", "--disk", "/dev/vdb"], [], timeout=30) == 1
    result = drive(["titan-install", "--recover", "--disk", "/dev/vda"],
                   [(b"Type RECOVER /dev/vda to continue:", b"RECOVER /dev/vda\n")], timeout=30)
    assert result == 0
    recovered = status()
    assert recovered["attempt"]["status"] == "recovered" and not recovered["live_mounts"]
    assert not recovered["target_exists"]
    # Recovery preserved the partial filesystems: verify their labels directly.
    assert command("blkid", "-s", "LABEL", "-o", "value", "/dev/vda2").strip() == "TITAN_ROOT"
    assert command("blkid", "-s", "LABEL", "-o", "value", "/dev/vda1").strip() == "TITAN_EFI"
    print("PASS  Cancel/wrong disk refuse; confirmed recovery preserves disk and allows a fresh attempt", flush=True)
