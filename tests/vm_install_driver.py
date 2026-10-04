#!/usr/bin/env python3
"""Drive only the interactive installer inside the disposable live QEMU guest."""
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


def install_command(repository):
    return ["titan-install", "--apply", "--disk", "/dev/vda", "--user", "tester",
            "--timezone", "UTC", "--vm-repo", repository]


def install_prompts():
    return [(b"Type ERASE /dev/vda to continue:", b"ERASE /dev/vda\n"),
            (b"New account password:", b"titanvm\n"),
            (b"Repeat password:", b"titanvm\n")]


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[2] == "--recovery":
        from vm_installer_recovery import check_recovery
        check_recovery(sys.argv[1])
    raise SystemExit(drive(install_command(sys.argv[1]), install_prompts()))
