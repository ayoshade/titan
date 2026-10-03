---
name: diagnose-crash
description: 'Diagnose why a program crashed on this machine, from a systemd-coredump core dump. Use when a process has segfaulted, aborted, or otherwise dumped core, when asked why an application crashed or disappeared, or when a "Process crashed:" desktop notification is acted on. Triggers: crash, segfault, SIGSEGV, SIGABRT, core dump, coredumpctl, "why did X crash", "X keeps crashing", backtrace symbolization.'
---

# Diagnose a crash from a core dump

Titan machines run Arch with `systemd-coredump` as the kernel core handler
(`/proc/sys/kernel/core_pattern` pipes to `systemd-coredump`). Cores are stored
zstd-compressed in `/var/lib/systemd/coredump/`, and a short stack trace is
written to the journal. `gdb`, `eu-stack` (elfutils) and Arch's debuginfod
server (`DEBUGINFOD_URLS=https://debuginfod.archlinux.org`) are available, so
backtraces can be fully symbolized without installing debug packages.

The work is read-only. Do not delete cores, restart the crashed program, attach
a debugger to a running process, or change the coredump configuration unless
the user asks.

## 1. Find the dump

```sh
coredumpctl list --no-pager --since today            # or -S "2026-10-03 07:00"
coredumpctl list --no-pager quickshell               # by executable name/path
coredumpctl list --no-pager -1                       # the most recent crash
```

- A "Process crashed: NAME" notification names the program. Match it to the
  newest row for that executable. If the user just says "it disappeared", list
  everything since roughly when it happened.
- The COREFILE column decides how far you can go:
  - **present:** full analysis is possible.
  - **missing:** the file was cleaned up by tmpfiles or rotated.
  - **none / truncated:** the core was over the size limits in
    `systemd-analyze cat-config systemd/coredump.conf`.
  - Without a core, you only have the journal trace from step 2.
- Your own processes need no sudo. Root or other users' processes need
  privileges. Do not ask for a password in chat; have the user run
  `! sudo coredumpctl info PID` themselves.

## 2. Read the metadata and the journal trace

```sh
coredumpctl info PID --no-pager
```

Record the following:

- **Executable, command line and unit:** these tell you which program and how
  it was started.
- **Signal and si_code** (see the table in step 5).
- **Timestamp and boot ID:** use them for the log search below.
- **Package:** `pacman -Qo /usr/bin/EXE`, then `pacman -Q PKG`.
- **The journal stack trace:** it is already partly symbolized from exported
  symbols and is often enough to see the shape of the crash.

Then read the logs around the timestamp. Fatal messages often appear there
rather than in the core:

```sh
journalctl -b -o short-precise --no-pager --since "HH:MM:SS-5s" --until "HH:MM:SS+2s"
journalctl --user -b --no-pager -o short-precise --since ... --until ...
```

Daemonized programs (for example, Quickshell started with `qs -d`) have no
stderr in the journal. Look for the application's own logs instead. Quickshell
writes `~/.cache/quickshell/crashes/<instance>/report.txt` and `log.qslog` for
crashes its handler catches. The run-time log is
`/run/user/$UID/quickshell/by-id/<instance>/`.

## 3. Get a backtrace fast (no downloads, about 1 s)

```sh
DEBUGINFOD_URLS= coredumpctl debug PID --debugger-arguments="-batch -nx \
  -iex 'set debuginfod enabled off' -ex 'set pagination off' \
  -ex 'bt 40' -ex 'info threads' -ex 'thread apply all bt 8'"
```

This gives demangled names for exported symbols (`QWindow::unsetCursor()`,
`abort()`), but internal functions show as `??`. Start interpreting from this
output, and only symbolize fully if the answer depends on internal frames,
arguments or the fatal message.

## 4. Symbolize fully with debuginfod (slow the first time)

```sh
coredumpctl debug PID --debugger-arguments="-batch -nx \
  -iex 'set debuginfod enabled on' -ex 'set pagination off' \
  -ex 'bt 40' -ex 'frame N' -ex 'info args' -ex 'info locals'"
```

- **First run:** gdb downloads debug info for every library in the process. A
  Qt/Quickshell core took over 4 minutes and about 3 GB of cache. Run it in the
  background or with a timeout of at least 25 minutes, and tell the user it is
  downloading.
- **Later runs:** fast. The same core took 15 s once cached.
- **Cache:** `~/.cache/debuginfod_client`. Deleting it is safe if space is
  needed; mention its size when you finish.
- **Partial upgrades:** if a library's debug info is not found, the installed
  package may not match what was running. Compare package versions with the
  crash time in `/var/log/pacman.log` (step 6).
- **Fatal messages:** full symbols show the message argument directly, for
  example in `QMessageLogger::fatal`, `__assert_fail`,
  `__libc_message`/`malloc_printerr` or `std::terminate`. Quote that string; it
  is usually the most useful single fact.
- **`eu-stack --core=FILE --executable=EXE`:** an alternative for a quick
  multi-thread view. Extract the core first with
  `coredumpctl dump PID -o "$SCRATCH/core"`, keep it in a scratch directory,
  and delete it afterwards.

## 5. Interpret

| Signal | si_code | Usual meaning |
| --- | --- | --- |
| SIGSEGV (11) | SEGV_MAPERR | Access to an unmapped address. A tiny fault address (`si_addr` near 0x0) is a null pointer; a garbage address is use-after-free or corruption |
| SIGSEGV (11) | SEGV_ACCERR | Write to read-only memory or execution of non-executable memory |
| SIGABRT (6) | SI_TKILL | The process aborted itself: `abort()`, a failed `assert`, a Qt `qFatal`, `std::terminate` (uncaught C++ exception), or glibc heap corruption ("free(): invalid pointer", "double free") |
| SIGBUS (7) | — | A mapped file shrank under it, or misaligned access |
| SIGILL (4) / SIGTRAP (5) | — | Illegal instruction: CPU feature mismatch, `__builtin_trap`, or a Rust/Go panic path |
| SIGFPE (8) | — | Integer division by zero |
| any | SI_USER | Another process sent the signal with `kill`; this is not a bug in the crashed program |

Rules for reading the stack:

- **Read past the crash handler.** Programs with their own crash handler (for
  example Quickshell's `qs::crash::signalHandler`) re-raise the signal, so the
  trace repeats. The real fault is the frames below `<signal handler called>`.
- **Find the first meaningful frame.** Skip libc and abort machinery (`raise`,
  `abort`, `__pthread_kill_implementation`). The first frame in the program or
  library that made the decision says *who* failed. The frames under it say
  *during what*: start-up, an event, teardown (destructors, `~QObject`,
  `exit`, `atexit`) or a worker thread.
- **Check other threads.** Use `thread apply all bt` for races and deadlocks.
  A crash in one thread while another holds a lock in the same subsystem is a
  strong lead.
- **Check recurrence.** `coredumpctl list EXE`: one crash is a data point;
  several with the same top frames are a reproducible bug.
- **Classify the cause**, and say which:
  - Titan configuration or code: QML, scripts, a bad setting.
  - An upstream bug: the program or a library.
  - The environment: partial upgrade, missing GPU driver, out of memory
    (`journalctl -k | grep -i "out of memory"` near the time), hardware.
  - Not a crash: killed by a user, a script or systemd. Check `SI_USER` and
    the unit's journal.

## 6. Check the context

- `grep -E "upgraded|installed" /var/log/pacman.log | tail -40`: did the
  program, Qt, Mesa or glibc change shortly before the crash? Arch partial
  upgrades (a library newer than the program built against it) are a classic
  cause.
- `uname -r` and the boot ID from `coredumpctl info`: is this the current
  boot?
- For Titan's own shell, look at `git log` in `~/dotfiles` around the crash
  time. A QML change, hot reload or `scripts/shell-restart` at that moment
  narrows things down a lot.

## 7. Report

Give the user a short answer first, then the evidence:

1. What crashed (program, PID, time) and the signal in plain words.
2. The cause, with confidence (*confirmed* by the fatal message or frames, or
   *likely* or *unclear*). Name the classification from step 5.
3. Five to ten key frames and any fatal message, quoted verbatim.
4. Whether it recurs, and what to do: a workaround, a Titan fix, an upstream
   bug report (include package versions and the symbolized trace), or nothing
   when it is harmless.
5. What was not checked.

Privacy: a core contains the process's memory (typed passwords, clipboard,
tokens, document contents).
- Never paste memory contents, environment variables or large hex dumps into
  chat or logs, and never upload a core anywhere.
- Backtraces and function arguments are fine to show, but redact strings that
  look like secrets or personal data.
- Delete any core you extracted with `coredumpctl dump`.

## Worked example (Titan, 2026-10-03)

- **Crash:** `coredumpctl list quickshell` showed SIGABRT cores from
  `qs -n -d -c umbra` at the moments the shell was restarted.
- **Fast backtrace:** a handler re-raise, then `abort` ←
  `QMessageLogger::fatal` ← `QWindow::unsetCursor()` ←
  `QQuickItemPrivate::derefWindow()` ← `QQuickItem::~QQuickItem()` ←
  `QObjectPrivate::deleteChildren()`.
- **Full symbols** (4 min the first time, 15 s cached) gave the message:
  `"QPixmap: Must construct a QGuiApplication before a QPixmap"`.
- **Cause:** during shutdown, QML items were destroyed after the
  `QGuiApplication` was gone. An item's cursor reset created a QPixmap, and Qt
  aborted. This is an upstream Quickshell 0.3.1 teardown bug, not Titan
  configuration. Its effect was that `qs kill` sometimes crashed or hung, which
  is why `scripts/shell-restart` now escalates to TERM and then KILL (see
  `docs/verification.md`).
