# Snapshots and recovery

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
