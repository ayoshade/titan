#!/usr/bin/env python3
"""Drive only the interactive installer inside the disposable live QEMU guest."""
import argparse
import os
import pty
import select
import sys
import time


def drive(command, prompts, *, env=None, on_data=None, timeout=1800):
    pid, terminal = pty.fork()
    if pid == 0:
        os.execvpe(command[0], command, os.environ if env is None else env)
    prompts = list(prompts)
    buffer = b""
    deadline = time.monotonic() + timeout
    try:
        while time.monotonic() < deadline:
            readable, _, _ = select.select([terminal], [], [], 1)
            if readable:
                try:
                    data = os.read(terminal, 65536)
                except OSError:
                    break
                if not data:
                    break
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
                buffer = (buffer + data)[-4096:]
                if prompts and prompts[0][0] in buffer:
                    _, answer = prompts.pop(0)
                    os.write(terminal, answer)
                    buffer = b""
                if on_data:
                    on_data(data)
        else:
            os.kill(pid, 15)
            raise RuntimeError("Installer test timed out")
        _, status = os.waitpid(pid, 0)
        return os.waitstatus_to_exitcode(status)
    finally:
        os.close(terminal)


def install_command(repository, bootloader="systemd-boot"):
    return ["titan-install", "--apply", "--disk", "/dev/vda", "--user", "tester",
            "--timezone", "UTC", "--vm-repo", repository, "--bootloader", bootloader]


def install_prompts():
    return [(b"Type ERASE /dev/vda to continue:", b"ERASE /dev/vda\n"),
            (b"New account password:", b"titanvm\n"),
            (b"Repeat password:", b"titanvm\n")]


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('repository')
    parser.add_argument('--recovery', action='store_true')
    parser.add_argument('--bootloader', choices=('systemd-boot', 'limine'), default='systemd-boot')
    args = parser.parse_args()
    if args.recovery:
        from vm_installer_recovery import check_recovery
        check_recovery(args.repository)
    raise SystemExit(drive(install_command(args.repository, args.bootloader), install_prompts()))
