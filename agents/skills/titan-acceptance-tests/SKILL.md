---
name: titan-acceptance-tests
description: Write, run, or diagnose Titan graphical acceptance tests and installed-disk validation in disposable QEMU VMs. Use for VM desktop integration testing, not tests that terminate applications in the user's active session.
---

# Titan graphical acceptance testing

Adapted from Omarchy's acceptance-tests guide. Read the checkout's `AGENTS.md`,
`docs/installation.md` and `docs/verification.md` before running a VM workflow.

Titan's current entrypoints are:

```sh
tools/vm-test --full             # packaged CLI/config checks
tools/vm-test --graphical        # ReGreet authentication, session, Welcome, IPC
tools/vm-test --workflows        # graphical + real runtimes/services/databases/apps
tools/vm-test --full --reuse RUN_DIRECTORY
```

`--graphical` implies full packages and kept artifacts. `--stay` deliberately
keeps QEMU running for debugging or ISO building. See `docs/installation.md`
for `vm-build-iso` followed by `vm-install-test`, which installs a new disk and
boots it with the ISO detached. These are Titan's own harnesses; it has no
Omarchy `test/acceptance.d` suite or sibling `omarchy-iso` checkout.

`--workflows` tests the local checkout only and keeps command logs, JSON
results, source hashes and terminal screenshots. It installs optional packages
inside the guest and tests Node, PHP/Laravel, the three optional services and
all five Docker databases sequentially. AUR/multilib checks exercise refusal
without the required helper/repository; they do not build an AUR package or
authenticate Tailscale. Expect PHP source compilation to take several minutes.
For a running `--graphical --stay` guest, `tools/vm-workflows RUN` runs only
this companion suite. Guest upgrades that replace the running kernel's modules
require a guest reboot; `vm-test` performs that before acceptance checks.
Use `tools/vm-workflows RUN --only apps` or `--only preservation` for focused
regressions after rebuilding the installed package. Inspect the captures even
when automated checks pass: a mapped terminal can still display config errors.
Do not edit a running Bash harness file; finish its run before changing it.

## Choose meaningful coverage

Reuse a stopped kept VM for focused package/test iterations. Exact local
package filenames must match the current checkout version; a prior archive in
the guest is not a valid substitute. For live installer, hardware, boot or
first-run changes, build a current ISO and test a fresh virtual disk. The
installer harness overlays `install.py` for iterations; final ISO verification
must establish that the image already contains that same source.

The graphical companion `tools/vm-graphical` uses QMP input and real PAM
authentication, checks live Hyprland errors and shell IPC, and captures greeter,
selection, login and desktop states. Extend assertions around the behavior
changed, including keyboard/focus and restart persistence where relevant.
Do not treat a running process alone as a loaded or usable UI.

## Isolate and restore

- Never pass host disks to QEMU or run application-killing/login tests in the
  active development desktop. Keep fixtures, credentials and user accounts
  strictly in the disposable guest.
- Capture current theme/settings before changes and restore them on success
  and failure. Track test-owned processes and files rather than broad kills;
  existing guest-wide restart behavior is acceptable only in the disposable VM.
- QMP virtual key input tests compositor-level shortcuts. Typing through a
  focused app is not equivalent evidence. QMP permits one monitor client at a
  time; close/release a capture client before a second harness connects.
- Store qcow2/build outputs in the disk-backed cache, not RAM-backed `/tmp`.
  Inspect available memory and run one VM at a time on the owner's laptop.
  Verify a kept VM's PID belongs to that run before stopping it.
- Test-only SSH keys and unsigned repos stay in the harness. Do not redistribute
  test images or expose their private keys through an HTTP directory.

Inspect captures rather than merely saving them. Preserve failure logs and
screenshots, stop task-owned VMs after checks unless deliberately kept, and
record exact assertions and remaining limits in `docs/verification.md`.
