#!/usr/bin/env python3
"""Drive only the interactive installer inside the disposable live QEMU guest."""
import os
import pty
import select
import sys
import time

pid, terminal = pty.fork()
if pid == 0:
    os.execvp("titan-install", ["titan-install", "--apply", "--disk", "/dev/vda",
              "--user", "tester", "--timezone", "UTC", "--vm-repo", sys.argv[1]])
prompts = [(b"Type ERASE /dev/vda to continue:", b"ERASE /dev/vda\n"),
           (b"New account password:", b"titanvm\n"),
           (b"Repeat password:", b"titanvm\n")]
buffer = b""
deadline = time.monotonic() + 1800
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
else:
    os.kill(pid, 15)
    raise SystemExit("Installer test timed out")
_, status = os.waitpid(pid, 0)
raise SystemExit(os.waitstatus_to_exitcode(status))
