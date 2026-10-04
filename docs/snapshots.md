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
deletes snapshots. Offline restore is described below. The ESP must retain at least
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
graphical preview and authenticated recovery UX remain open.

## Experimental offline Limine restore

Boot the current Titan live ISO under UEFI in the dedicated-disk QEMU VM.
The target disk must be completely unmounted. This interface refuses the
installed desktop, snapshot preview, physical machines, multi-device Btrfs,
extra partitions, active swap and block-device holders. It applies only to
Titan's unencrypted Limine layout; host Snapper snapshots are a separate system.

```sh
titan snapshot list --disk /dev/vda --json
titan snapshot restore ID --disk /dev/vda
titan snapshot restore-status --disk /dev/vda --json
titan snapshot restore-resume --disk /dev/vda
```

Use an ID from the live inventory or `titan snapshot list` on the installed
system. Both restore and resume require the exact text `RESTORE ID /dev/vda`. There is no
automatic confirmation or reboot. Status mounts the target filesystems
read-only, with Btrfs log replay disabled, and makes no persistent writes.
It returns either the schema-1 journal or `{"schema":1,"restore":null}`. Btrfs
inspection uses `ro,rescue=nologreplay`; the standalone `nologreplay` spelling
is not accepted by the tested live kernel.

Restore validates the source's read-only property, installer plan, filesystem
UUIDs, fstab, kernel/module match and saved asset hashes. The fstab must select
the supported subvolumes by name, without stale numeric `subvolid` bindings.
Restore stages a writable copy of the captured root, retains the displaced root as
`@titan-before-ID-TRANSACTION`, and installs the new root at `@`. Separate
`@home`, `@log` and `@pkg` volumes retain their latest contents. The captured
system configuration and packages are restored; personal choices under the
separate home volume remain current.

The ESP gets the captured kernel/initramfs pair, a newly generated menu using
the captured appearance settings, and the captured Limine EFI binary. Other
ordinary kernel entries are removed from the active menu because their modules
may be absent from the restored root. All displaced ordinary images, menu and
EFI binary are retained under `/boot/titan/restores/ID-TRANSACTION/before/`;
snapshot assets and other ESP files remain present. Run `titan boot refresh`
normally after booting the restored system; future full package upgrades can
regenerate additional kernels and menus through the existing hook.

The durable journal is `titan-restore/journal.json` at the Btrfs top level,
outside `@`. Its phases are `preparing`, `staged`, `root-saved`, `root-installed`,
`boot-installed` and `complete`. Resume verifies recorded subvolume identities
and hashes; it handles a root or boot-file rename completing before the next
checkpoint. Previous completed journals are retained on subsequent restores.
The live installer and restore share an operation lock, inherited by workers.

If interrupted, boot the live ISO again, inspect `restore-status`, and use
`restore-resume` with a new typed confirmation. During the two root renames
`@` can be temporarily absent, so do not boot the installed disk until the
journal says `complete`. A forcibly killed command may leave its recovery
mounts in the live session; a fresh live boot releases those and resumes from
the persistent journal. Busy mounts are never lazily or forcibly unmounted.
An unexpected subvolume identity, backup, staged asset or destination change
causes refusal and needs manual inspection. No snapshot, displaced root or backup is
automatically deleted.

This restores one captured root and its saved kernel pair; it is not encryption,
dual-boot, Secure Boot, physical-machine recovery, filesystem repair or a
Snapper integration. Available space must cover the retained boot backups,
staging and a 64 MiB ESP reserve; Btrfs metadata exhaustion still reports a
failure and retains the journal for inspection. Graphical preview, automatic
Snapper menu synchronization and bounded snapshot capacity remain open.

Design references: Btrfs documents [writable snapshot creation](https://btrfs.readthedocs.io/en/latest/btrfs-subvolume.html)
and the need for [nologreplay with read-only inspection](https://btrfs.readthedocs.io/en/latest/ch-mount-options.html).

Primary implementation references: Arch's [sd-volatile hook](https://github.com/archlinux/mkinitcpio/blob/master/install/sd-volatile)
and systemd's [fstab/volatile parameters](https://github.com/systemd/systemd/blob/main/man/systemd-fstab-generator.xml).
