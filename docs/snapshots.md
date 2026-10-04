# Snapshots and recovery

The existing-install Snapper workflow below is independent of the
[experimental Limine previews](#experimental-limine-recovery-previews). Neither
interface changes the development laptop's bootloader.

Titan uses Snapper on the Btrfs root so system changes can be undone. Enable it
once with `scripts/install-snapshots`; it asks for sudo. Run
`scripts/install-snapshots --dry-run` first to see exactly what it will do.
Run a full `titan update` beforehand, so packages install from a current
database.

## What gets snapshotted

| Path | Covered? |
| --- | --- |
| `/` (subvolume `@`) | Yes |
| `/home` (`@home`), `/var/log` (`@log`), `/var/cache/pacman/pkg` (`@pkg`) | No (separate subvolumes); rolling back the system never rewinds your files, logs or the package cache |
| `/boot` (vfat, systemd-boot) | No; the kernel and initramfs there are not snapshotted |

Snapshots are taken at these times:

- Before and after every pacman transaction (`snap-pac`).
- Before each `titan update`, labelled `titan update DATE`.

There is no hourly timeline. Cleanup keeps the last 10 numbered snapshots and
5 marked important (`snapper-cleanup.timer`).

## Inspect and undo

```sh
snapper -c root list                      # numbers, dates, descriptions (no sudo needed)
snapper -c root status 41..42             # files changed between pre (41) and post (42)
snapper -c root diff 41..42 /etc/foo      # a single file's diff
sudo snapper -c root undochange 41..42    # revert those changes in the running system
```

`undochange` suits configuration or small package regressions. After undoing
a package transaction, run `sudo pacman -Syu` again to bring the system back
to a consistent package set; Arch does not support partial states.

## Full rollback (system will not work)

systemd-boot cannot boot Btrfs snapshots directly, so a full rollback is done
from a live USB or another boot entry:

1. Boot an Arch ISO and mount the Btrfs volume:
   `mount -o subvolid=5 /dev/nvme0n1p2 /mnt`.
2. Find the snapshot: `ls /mnt/@/.snapshots/*/info.xml`. Read the
   descriptions or dates.
3. Move the broken root aside:
   - `mv /mnt/@ /mnt/@broken`
   - `btrfs subvolume snapshot /mnt/@broken/.snapshots/N/snapshot /mnt/@`
4. If the kernel in `/boot` no longer matches the snapshot's
   `/usr/lib/modules`, chroot in and reinstall `linux` so `/boot` matches.
5. Reboot. Delete `@broken` once everything works.

Test this procedure in a VM before relying on it. It has not been rehearsed on
the daily laptop.

## Remove

```sh
sudo snapper -c root delete-config        # deletes the config and its snapshots
sudo pacman -Rns snap-pac snapper
```

## Experimental Limine recovery previews

Fresh, dedicated-disk UEFI QEMU Titan installations using Limine support:

```sh
titan snapshot list --json
sudo titan snapshot create --description "Before changing the system"
sudo titan boot refresh
```

These commands use original Bash operations, separate from Snapper. Creation
captures the running kernel's root as a read-only Btrfs subvolume at
`@titan-snapshots/ID`, stores matching kernel/initramfs copies and a JSON
manifest under `/boot/titan/snapshots/ID`, then refreshes the Limine menu.
It holds the pacman lock throughout capture, removes that capture-owned lock
from the private copy and seals the subvolume read-only before publishing it.
It checks the installed kernel image
against the running version's module tree and verifies the initramfs includes
that version and Arch's `sd-volatile` hook. Boot refresh validates manifest
fields and copied asset hashes before replacing the menu. A package update
that replaced the running kernel requires booting the current kernel first.

Select **Titan snapshot ID (temporary recovery preview)** in Limine. The
snapshot's saved kernel boots its read-only root through
`systemd.volatile=overlay`; all ordinary writes go to temporary memory and
disappear on reboot. The command line disables fstab and GPT automounts in
both initrd and the running system. `/home`, `/var/log`, the package cache and
the ESP stay unmounted. The preview enters `multi-user.target`, a text recovery
session; the normal user home and graphical desktop are unavailable. System
accounts/configuration come from the captured root. It is not an isolated
security environment: a privileged operator could deliberately mount disks.

The normal boot entries remain available. Creation never reboots, restores or
deletes snapshots; there is no restore command yet. The ESP must retain at least
64 MiB free after the copied assets, and each snapshot adds another copy of one
kernel/initramfs pair. Listing is a manifest inventory, not a full filesystem
integrity check. Never manually modify the copied images or their manifests.
If menu publication fails after capture, recovery data stays on disk for
inspection and a later `titan boot refresh`; partial data is not silently removed.

Fresh Limine installs include `sd-volatile` in their generated mkinitcpio hooks.
Older experimental VMs must explicitly add it after `filesystems` in their
systemd-based hook list, rebuild with `mkinitcpio -P` and refresh the menu.
No existing-machine migration performs this change. This was rehearsed only in
the disposable VM; host Snapper snapshots are not automatically exported into
the Limine menu. Automatic pre-upgrade capture, cleanup/capacity management,
graphical preview, authenticated recovery UX and confirmed offline restore with
matching boot files are the next milestones.

Primary implementation references: Arch's [sd-volatile hook](https://github.com/archlinux/mkinitcpio/blob/master/install/sd-volatile)
and systemd's [fstab/volatile parameters](https://github.com/systemd/systemd/blob/main/man/systemd-fstab-generator.xml).
