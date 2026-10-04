---
name: titan-installation
description: Develop Titan bootstrap, per-user setup, hardware profiles, package installation, login setup, or experimental ISO and disk installer code. Use in a source checkout; test privileged installation work in disposable QEMU VMs.
---

# Titan installation development

Adapted from Omarchy's install-scripts guide. Read the checkout's `AGENTS.md`,
`docs/distribution.md` and `docs/installation.md` for the actual install scope.

The [agent reference library](../../../docs/research/agent-references.md) links
the pinned [Omarchy checkout](/home/shade/.cache/titan/references/omarchy) and
the [Quickshell archive](/home/shade/.webfetch/quickshell/index.md). Use upstream
installation workflows as behavior references; preserve Titan's VM guards.

## Ownership boundaries

| Layer | Titan source |
| --- | --- |
| Development config links | `scripts/bootstrap` (refuses unrelated existing files) |
| Per-user defaults and state | `titan setup` in `bin/titan`; `bin/titan-session` invokes it on first login |
| Agent skill links | `scripts/install-agent-skills`, also used by setup and update |
| Packages | `packages/*.txt`, `packaging/titan*/PKGBUILD` |
| Read-only hardware inventory | `lib/titan/hardware.py`, `system/hardware/profiles.json` |
| Live installer | `bin/titan-install`, `lib/titan/install.py`, `installation/packages.txt` |
| ISO and VM orchestration | `tools/build-iso`, `tools/vm-build-iso`, `tools/vm-install-test` |
| Reviewed privileged templates | `system/`, installed through the relevant `scripts/install-*` |

Titan's scripts are separate executable programs with their own shebangs and
strict error handling, not Omarchy's sourced setup leaves. Resolve paths from
the entrypoint and pass explicit context; do not introduce `OMARCHY_PATH`,
`OMARCHY_INSTALL` or helpers Titan does not ship.

Setup must be repeatable and preserve user overrides. Defaults belong in the
package, personal values in the user layer, and generated files/markers in
machine state. A state directory containing only `setup.log` is a fresh user:
the session creates it before setup. Do not run legacy welcome migrations there.
An existing-install layout change needs an idempotent migration.

Keep privileged machine setup separate from per-user configuration. Inspect
existing services before replacing them. Use full Arch upgrades; avoid partial
upgrades. Inventory a dependency before assuming it exists on a fresh machine.
Do not apply the owner's always-awake/Performance policy to all installations.

## Preserve installer boundaries

The current installer applies only as root inside a booted QEMU/KVM UEFI live
ISO. It requires an unused whole disk, compatible repository, exact typed erase
confirmation and terminal password entry. Keep checks before the first write
and recheck immediately before erase. Do not remove the VM guard to test on the
daily-use laptop, pass host disks to QEMU, or log account passwords.

The unsigned repository and SSH keys in the VM harness are development fixtures.
Normal installation uses the pinned signing identity and signed packages.
Never distribute a test ISO containing the temporary SSH public key.

## Verify the resulting installation

Run focused safety/setup tests and `scripts/doctor` first. For installation
changes, build inside QEMU, install on a new virtual disk, detach the ISO and
boot that disk. Use the commands in `docs/installation.md`; verify ReGreet login,
first-login Welcome, shell IPC, Btrfs mounts and compositor errors. A cloud-image
package test alone does not establish installer correctness.

Record build inputs, logs, failures and untested hardware in
`docs/verification.md`. Publish/sign only under the owner's release instruction;
do not handle their signing key or passphrase.
