# Experimental installation (Phase 2)

The 0.3.0 development tree adds a UEFI live ISO and a dedicated-disk
installer. **Apply is currently limited to disposable QEMU VMs.** The public
repository still contains 0.2.0; 0.3.0 has not been published. The installer
checks repository compatibility before any erase, so development tests use a
local repository built from this checkout.

The initial scope is x86_64, UEFI/systemd-boot, one whole disk of at least
32 GiB, an unencrypted Btrfs root and a 1 GiB EFI partition mounted at `/boot`.
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
scripts/titan-install                 # list whole disks (no root needed)
scripts/titan-install --disk /dev/vda --user titan --timezone UTC --json
```

The last command prints a plan and refuses mounted disks, active swap,
device-mapper/RAID holders, read-only disks, partitions and undersized targets.
It changes nothing. `--apply` additionally requires root, a booted Archiso live
environment, UEFI, QEMU/KVM, a working compatible repository and a terminal.
It rechecks the disk immediately before writes. The user must type
`ERASE /dev/vda` (the exact selected path) and enter the new account password
twice in that terminal. Passwords are never command arguments or log output.

Failures stop the installer and unmount its target. `/mnt/titan-target` remains
as a retry marker: inspect the log and `findmnt` before retrying. The prototype
does not resume a half-finished installation. Starting a new throwaway VM is
the simplest recovery.

## Build and test in QEMU

```sh
scripts/vm-test --graphical --stay
# Copy the printed RUN_DIRECTORY into the next commands:
scripts/vm-build-iso RUN_DIRECTORY
# Stop just that build VM to release its 2 GiB memory, then:
scripts/vm-install-test RUN_DIRECTORY
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

Full builds and installs use 2 GiB guest memory and require 3 GiB available on
the host. Run one VM at a time on the development laptop. Files stay on disk,
outside Git; do not put overlays or Archiso work trees in RAM-backed `/tmp`.

## ISO builder

Inside an isolated QEMU build machine with Archiso installed:

```sh
scripts/build-iso --prepare /var/tmp/titan-profile  # stage only, no root needed
sudo scripts/build-iso /var/tmp/titan-build        # new directory, actual build
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

Before a public ISO release: add encryption and installer recovery, widen VM
coverage, test the signed 0.3.0 repository installation, finish physical GPU
and laptop profiles, verify boot/login visuals at multiple resolutions, and
review distribution/source-license obligations for all ISO packages. Build a
new image without `--ssh-key`, sign it through the owner's normal release
process, and publish only when requested.
