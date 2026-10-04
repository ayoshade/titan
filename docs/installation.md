# Experimental installation (Phase 2)

The 0.3.0 development tree adds a UEFI live ISO and a dedicated-disk
installer. **Apply is currently limited to disposable QEMU VMs.** The public
repository still contains 0.2.0; 0.3.0 has not been published. The installer
checks repository compatibility before any erase, so development tests use a
local repository built from this checkout.

The initial scope is x86_64, UEFI (systemd-boot by default, opt-in Limine),
one whole disk of at least 32 GiB, an unencrypted Btrfs root and a 1 GiB EFI partition mounted at `/boot`.
It creates `@`, `@home`, `@log` and `@pkg`, with zstd compression. The account
uses a US keyboard and en_US.UTF-8; its timezone and hostname are configurable.
Root password login is locked; the new account belongs to wheel and uses its
own password for sudo. Installation does not reboot automatically.

Not implemented: encryption, dual boot, manual partitioning, Secure Boot,
BIOS installs, a graphical installer or physical-machine installation. NVIDIA
and unknown GPU profiles refuse automatic installation. Intel and AMD package
selection has fixture coverage; physical GPUs and laptop behavior still need
hardware testing. Power-policy work remains Phase 3; the development laptop's
always-awake policy is never copied into a fresh installation.

## Read-only inspection

```sh
titan hardware --json                 # CPU/GPU/laptop inventory and packages
bin/titan-install                 # list whole disks (no root needed)
bin/titan-install --disk /dev/vda --user titan --timezone UTC --json
```

The last command prints a plan and refuses mounted disks, active swap,
device-mapper/RAID holders, read-only disks, partitions and undersized targets.
It changes nothing. `--apply` additionally requires root, a booted Archiso live
environment, UEFI, QEMU/KVM, a working compatible repository and a terminal.
It rechecks the disk immediately before writes. The user must type
`ERASE /dev/vda` (the exact selected path) and enter the new account password
twice in that terminal. Passwords are never command arguments or log output.

## Opt-in Limine in a fresh VM

```sh
bin/titan-install --disk /dev/vda --user titan --bootloader limine --json
# In the live QEMU ISO, repeat with --apply after reviewing the plan.
titan boot status --json
sudo titan boot refresh              # installed Titan Limine VM only
```

The Limine choice adds the official Arch `limine` package and includes `jq`
in the base plan; `jq` is also a Titan package dependency for Shell JSON
operations. The installer writes a Titan appearance file to `/etc/titan/limine.conf` and
installs a pacman hook for supported kernel and Limine/Titan transactions.
The original Bash helper `scripts/titan-boot` generates `/boot/limine.conf`
and deploys `/usr/share/limine/BOOTX64.EFI` to the fresh target's UEFI fallback
path `/boot/EFI/BOOT/BOOTX64.EFI`. It does not register NVRAM entries.
Configuration follows the [Limine 12.9.1 reference](https://github.com/Limine-Bootloader/Limine/blob/v12.9.1/CONFIG.md).

Refresh checks root, QEMU/KVM, UEFI, the installer plan and matching Btrfs `@`
root/UUID plus a mounted FAT `/boot` before writes. It refuses linked paths,
unmanaged menus and incomplete kernel/initramfs pairs. Linux, LTS, Zen and
Hardened image pairs are supported; only Linux and LTS have VM acceptance.
Changed generated menus and EFI binaries retain their prior contents as
`.previous`; these are file backups, not a complete system rollback.
The user's appearance file is preserved. No existing-machine bootloader
migration is provided, and the laptop remains on systemd-boot.

Limine snapshot entries, matched historical kernel/module assets, read-only
snapshot overlay boot and an explicit restore workflow remain unimplemented.
The existing Snapper tooling is unchanged. Installing Limine does not complete
snapshot recovery. See the [boot port batch](research/omarchy-port-plan.md#boot).
The live ISO continues to use Archiso's systemd-boot path; this choice controls
the bootloader on the newly installed virtual disk.

## Recover an interrupted attempt

In the same live QEMU boot, inspect the last checkpoint and current mounts:

```sh
titan-install --status --json
titan-install --recover --disk /dev/vda
```

`--status` is read-only and always prints JSON. Its schema-1 response contains
`attempt`, `busy`, `target_exists` and `live_mounts`. An attempt records its
disk identity, filesystem UUIDs, intended mounts, step, status and update time.
Steps cover partitioning, filesystems, base packages, system configuration,
desktop packages, services, bootloader, initramfs and unmounting. It never
records account passwords, subprocess input or subprocess output.

Ordinary failures retain their original exit error, record `failed` and try to
unmount verified target filesystems. An interrupt leaves the mounts for explicit
recovery. `/mnt/titan-target` and `/run/titan-installer/attempt.json` block a new
attempt until recovery. A lock prevents competing operations; child commands
inherit it so recovery remains blocked if a forcibly killed installer leaves
a worker alive. Wait for that worker to finish before trying recovery.

Recovery requires root, the live ISO, UEFI/QEMU, an interactive terminal and
the exact confirmation `RECOVER /dev/vda`. It checks the live boot, recorded
disk identity/size, filesystem UUIDs, source partitions and subvolume roots,
and current mounts again after confirmation.
It refuses changed devices, outside mounts/swap, storage holders, foreign or
unrecorded mounts and busy filesystems. There is no forced/lazy unmount. If a
killed chroot leaves unrecorded virtual filesystems, inspect and release those
manually in the disposable VM before retrying recovery.

On success it unmounts the verified target, removes only the empty retry
directory and records `recovered`. Partial files on disk are preserved for
inspection. A new `--apply` starts from scratch and requires its own `ERASE`
confirmation; this does not resume a half-configured system. Completed installs
record `installed`/`complete` and remove the empty target directory.

The recovery journal is live-session state: it does not survive rebooting the
ISO. Save its JSON and terminal log before leaving that session if needed.
After a live reboot there are no installer mounts to release; inspect the
partial disk and explicitly choose a fresh installation. Invalid arguments
exit 2, refused/failed operations exit 1, and an interrupt exits 130.
`--json` cannot be combined with the mutating `--apply` or `--recover` actions.

## Build and test in QEMU

```sh
tools/vm-test --graphical --stay
# Copy the printed RUN_DIRECTORY into the next commands:
tools/vm-build-iso RUN_DIRECTORY
# Stop just that build VM to release its 2 GiB memory, then:
tools/vm-install-test RUN_DIRECTORY
# Include failure/interruption and safe-recovery checks before installing:
tools/vm-install-test RUN_DIRECTORY --recovery
# Fresh opt-in Limine install, kernel refresh and upgraded-disk boot:
tools/vm-install-test RUN_DIRECTORY --bootloader limine
```

`vm-test --graphical` implies `--full --keep`. It drives real ReGreet
authentication through QEMU's monitor, starts the Titan session on a fresh
account, checks live compositor errors, shell IPC and Welcome, and captures
greeter/selection/login/desktop frames plus logs. It uses software rendering
with the VGA device in `qemu-base`; no additional host display modules are
required. `--stay` deliberately leaves that VM running for debugging; without
it QEMU stops on exit. Stop a kept VM by verifying its PID and command line
against `RUN_DIRECTORY/qemu.pid`, then sending that QEMU process TERM.
`--reuse RUN_DIRECTORY` repeats tests on its kept overlay and preserves test
theme/settings choices. Neither flag passes host disks through to the guest.

`vm-build-iso` stages only installer source and public data, installs Archiso
through a full upgrade **inside the VM**, and builds there as root. It copies
the ISO, checksum and build-input record back into `RUN_DIRECTORY/iso`. The
test ISO contains the throwaway VM's SSH public key. Never distribute it.
No private key or account password is embedded in the ISO.

`vm-install-test` starts a second VM with OVMF and a new 40 GiB qcow2 disk.
It serves an unsigned development repository to that VM only, drives the
installer's actual erase and password prompts, then adds test-only SSH access
to the installed target. It detaches the ISO, boots the new disk and repeats
graphical first-login checks. The test overlays current installer code for
development iterations; a final ISO check must use an image containing the
same code. Test SSH keys, SSH enablement and passwordless test access are
never part of the normal installer. Artifacts are kept and QEMU stops on exit.

`--recovery` injects a failing package step and a killed installer before any
base-package installation. It checks checkpoints, ordinary cleanup, inherited
worker locking, foreign/busy mount refusal, cancelled/wrong-disk recovery,
confirmed cleanup preserving filesystem labels, and a subsequent fresh install.
These fixtures exist only in the VM test harness, not the shipped installer.

Full builds and installs use 2 GiB guest memory and require 3 GiB available on
the host. Run one VM at a time on the development laptop. Files stay on disk,
outside Git; do not put overlays or Archiso work trees in RAM-backed `/tmp`.

## ISO builder

Inside an isolated QEMU build machine with Archiso installed:

```sh
tools/build-iso --prepare /var/tmp/titan-profile  # stage only, no root needed
sudo tools/build-iso /var/tmp/titan-build        # new directory, actual build
```

The builder starts from the installed
[Archiso releng profile](https://github.com/archlinux/archiso), retains its boot
paths, applies Titan's identity, uses UEFI boot and zstd SquashFS, and adds
Titan's original installer. The installed target uses signed Titan packages
by default; `--vm-repo http://10.0.2.2:PORT/repo` is the explicit unsigned
development path inside QEMU. There is no host sudo or signing-key handling in
the VM wrappers. Do not delete an interrupted Archiso work tree until `findmnt`
confirms none of its paths are still mounted.

## Hardware, login and boot

`system/hardware/profiles.json` is the package-selection catalog. Detection
reads sysfs and CPU vendor data; no monitor name, username, backlight device
or workstation identity is hard-coded. The machine's plan is retained in
`/etc/titan/install-plan.json`. User overrides remain in the existing user
layer and setup never replaces them.

The installer enables NetworkManager, Bluetooth, power-profiles-daemon and
the themed greetd/ReGreet login. The complete desktop meta-package also
includes these services, UPower and PipeWire. A virtual machine can lack a
power-profile backend or a Bluetooth adapter; that is different from a missing
package. Firewall policy and portable laptop power defaults remain Phase 3.

The original Plymouth theme is a dark background, centered Titan wordmark
and subdued progress dots. It reacts to boot progress without a refresh
timer, preserves message/password/question callbacks, and is copied only
into the new target. Its mkinitcpio hooks and `quiet splash` kernel options
are installed there; the development laptop's bootloader/initramfs are not
touched. Escape reveals boot details; systemd-boot's menu can edit the kernel
line to remove `quiet splash` for recovery.

## Reference decisions and next steps

The [Omarchy installation documentation](https://omarchy.org/manual/getting-started/)
was reviewed for its integrated ISO, explicit disk choice, first-run setup and
VM-first experience. Titan adopts the integrated path and visible confirmation
with its own installer and package/session interfaces. Omarchy's encrypted
and dual-boot installs are broader than this prototype; they were not copied
or claimed as implemented. Archiso provides the upstream live boot plumbing;
Titan writes its own installation, hardware and desktop integration.

Before a public ISO release: add encryption, widen VM
coverage, test the signed 0.3.0 repository installation, finish physical GPU
and laptop profiles, verify boot/login visuals at multiple resolutions, and
review distribution/source-license obligations for all ISO packages. Build a
new image without `--ssh-key`, sign it through the owner's normal release
process, and publish only when requested.
