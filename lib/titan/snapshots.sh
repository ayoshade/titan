# Original experimental snapshot previews, independent of the host's Snapper config.
titan_snapshot_manifest() {
 local directory=$1 uuid=$2 id=${1##*/}
 [[ $id =~ ^[0-9]{8}T[0-9]{6}Z-[a-zA-Z0-9]{6}$ ]] || { titan_boot_fail 'Invalid snapshot directory'; return 1; }
 titan_boot_path "$directory/manifest.json" || return
 jq -e --arg id "$id" --arg uuid "$uuid" '
  .schema == 1 and .id == $id and .root_uuid == $uuid and
  .subvolume == ("@titan-snapshots/" + $id) and
  (.description | type == "string") and (.created | type == "string") and
  (.kernel.name | type == "string" and test("^linux(-(lts|zen|hardened))?$")) and
  (.kernel.version | type == "string" and test("^[a-zA-Z0-9._+-]+$")) and
  (.kernel.image_sha256 | type == "string" and test("^[a-f0-9]{64}$")) and
  (.kernel.initramfs_sha256 | type == "string" and test("^[a-f0-9]{64}$"))' \
  "$directory/manifest.json" >/dev/null || { titan_boot_fail "Invalid snapshot manifest: $id"; return 1; }
 local file expected actual field
 for file in vmlinuz initramfs.img; do
  titan_boot_path "$directory/$file" || return
  [[ -f $directory/$file ]] || { titan_boot_fail "Missing snapshot boot asset: $id/$file"; return 1; }
  field=image_sha256; [[ $file != initramfs.img ]] || field=initramfs_sha256
  expected=$(jq -er ".kernel.$field" "$directory/manifest.json") || return
  actual=$(sha256sum -- "$directory/$file") || return
  [[ ${actual%% *} == "$expected" ]] || { titan_boot_fail "Snapshot boot asset hash mismatch: $id/$file"; return 1; }
 done
}

titan_snapshot_render() {
 local uuid=$1 esp=$2 directory id
 [[ ! -e $esp/titan/snapshots && ! -L $esp/titan/snapshots ]] && return 0
 titan_boot_path "$esp/titan/snapshots/.path-check" || return
 command -v jq >/dev/null || { titan_boot_fail 'Snapshot entries require jq'; return 1; }
 for directory in "$esp"/titan/snapshots/*; do
  [[ -e $directory || -L $directory ]] || continue
  titan_snapshot_manifest "$directory" "$uuid" || return
  id=${directory##*/}
  # Ignore fstab and GPT automounts: separate writable volumes and the ESP
  # must remain unmounted. Recovery preview deliberately uses a text session.
  printf '\n/Titan snapshot %s (temporary recovery preview)\n    protocol: linux\n    path: boot():/titan/snapshots/%s/vmlinuz\n    module_path: boot():/titan/snapshots/%s/initramfs.img\n    cmdline: root=UUID=%s ro rootflags=subvol=@titan-snapshots/%s systemd.volatile=overlay rd.fstab=no fstab=no rd.systemd.gpt_auto=no systemd.gpt_auto=no systemd.unit=multi-user.target\n' \
   "$id" "$id" "$id" "$uuid" "$id" || return
 done
}

titan_snapshot_list() {
 if [[ ! -e /boot/titan/snapshots && ! -L /boot/titan/snapshots ]]; then
  printf '%s\n' '{"schema":1,"experimental":true,"snapshots":[],"restore_supported":true,"restore_scope":"live UEFI QEMU ISO only"}'
  return
 fi
 titan_boot_path /boot/titan/snapshots/.path-check || return
 command -v jq >/dev/null || { titan_boot_fail 'Snapshot listing requires jq'; return 1; }
 local directory
 for directory in /boot/titan/snapshots/*; do
  [[ -e $directory || -L $directory ]] || continue
  titan_boot_path "$directory/manifest.json" || return
  jq -e '.' "$directory/manifest.json" || return
 done | jq -s '{schema:1,experimental:true,snapshots:.,restore_supported:true,restore_scope:"live UEFI QEMU ISO only"}'
}

titan_snapshot_create() (
 set -euo pipefail
 titan_boot_guard
 local description=$1 uuid=$titan_boot_uuid version name image initramfs contents bytes available id created work stage
 version=$(uname -r)
 [[ $version =~ ^[a-zA-Z0-9._+-]+$ ]] || { titan_boot_fail 'Invalid running kernel version'; exit 1; }
 name=$(cat "/usr/lib/modules/$version/pkgbase")
 [[ $name =~ ^linux(-(lts|zen|hardened))?$ ]] || { titan_boot_fail 'Unsupported running kernel'; exit 1; }
 image=/boot/vmlinuz-$name; initramfs=/boot/initramfs-$name.img
 titan_boot_path "$image"; titan_boot_path "$initramfs"
 titan_boot_path /boot/titan/snapshots/.path-check
 [[ ! -L /run/titan-snapshot.lock ]] || { titan_boot_fail 'Snapshot lock must not be linked'; exit 1; }
 exec 8>/run/titan-snapshot.lock
 flock -n 8 || { titan_boot_fail 'Another snapshot creation is running'; exit 1; }
 # Own the pacman lock for the complete capture: kernel files, initramfs,
 # module tree and package database must belong to the same installed state.
 titan_boot_path /var/lib/pacman/db.lck
 (set -o noclobber; : >/var/lib/pacman/db.lck) 2>/dev/null || { titan_boot_fail 'A package transaction is running'; exit 1; }
 work=''; stage=''
 trap '[[ -z $work ]] || { if mountpoint -q "$work"; then umount "$work" || true; fi; rmdir "$work" 2>/dev/null || true; }; [[ -z $stage ]] || rm -rf -- "$stage"; rm -f /var/lib/pacman/db.lck' EXIT
 cmp -s -- "$image" "/usr/lib/modules/$version/vmlinuz" || { titan_boot_fail 'Running kernel and installed boot image differ; boot the current kernel first'; exit 1; }
 contents=$(lsinitcpio "$initramfs")
 [[ $contents == *"usr/lib/modules/$version/"* && $contents == *'usr/lib/systemd/systemd-volatile-root'* && $contents == *'/overlay.ko'* ]] || {
  titan_boot_fail 'Rebuild the current initramfs with the systemd and sd-volatile hooks before creating a preview'; exit 1;
 }
 # Catch invalid existing menus/manifests before capturing more recovery data.
 local first
 IFS= read -r first </boot/limine.conf
 [[ $first == "$titan_boot_marker" ]] || { titan_boot_fail 'Refusing an unmanaged Limine configuration'; exit 1; }
 titan_boot_render "$uuid" /boot /etc/titan/limine.conf >/dev/null
 bytes=$(( $(stat -c %s "$image") + $(stat -c %s "$initramfs") + 64*1024*1024 ))
 available=$(df -B1 --output=avail /boot | tail -1)
 ((available > bytes)) || { titan_boot_fail 'Insufficient ESP space (keep 64 MiB free after copying boot assets)'; exit 1; }
 stage=$(mktemp -d /boot/.titan-snapshot.XXXXXX)
 id="$(date -u +%Y%m%dT%H%M%SZ)-${stage##*.}"
 created=$(date -u +%FT%TZ)
 cp -- "$image" "$stage/vmlinuz"
 cp -- "$initramfs" "$stage/initramfs.img"
 local image_hash initramfs_hash
 image_hash=$(sha256sum "$stage/vmlinuz"); image_hash=${image_hash%% *}
 initramfs_hash=$(sha256sum "$stage/initramfs.img"); initramfs_hash=${initramfs_hash%% *}
 jq -n --arg id "$id" --arg uuid "$uuid" --arg name "$name" --arg version "$version" \
  --arg description "$description" --arg created "$created" --arg image "$image_hash" --arg initramfs "$initramfs_hash" \
  '{schema:1,id:$id,root_uuid:$uuid,subvolume:("@titan-snapshots/"+$id),description:$description,created:$created,capture_pacman_lock_removed:true,
    kernel:{name:$name,version:$version,image_sha256:$image,initramfs_sha256:$initramfs}}' >"$stage/manifest.json"
 work=$(mktemp -d /run/titan-snapshot.XXXXXX)
 mount -t btrfs -o subvolid=5 "UUID=$uuid" "$work"
 if [[ ! -e $work/@titan-snapshots && ! -L $work/@titan-snapshots ]]; then
  btrfs subvolume create "$work/@titan-snapshots" >&2
  chmod 700 "$work/@titan-snapshots"
 fi
 [[ ! -L $work/@titan-snapshots ]] && btrfs subvolume show "$work/@titan-snapshots" >/dev/null || {
  titan_boot_fail 'Snapshot container must be a Btrfs subvolume'; exit 1;
 }
 sync -f /
 # Build privately, remove only our capture lock from the new copy, then seal
 # it read-only before publication. The live root's lock stays held throughout.
 btrfs subvolume snapshot / "$work/@titan-snapshots/$id" >&2
 titan_boot_path "$work/@titan-snapshots/$id/var/lib/pacman/db.lck"
 rm -- "$work/@titan-snapshots/$id/var/lib/pacman/db.lck"
 btrfs property set -ts "$work/@titan-snapshots/$id" ro true
 [[ $(btrfs property get -ts "$work/@titan-snapshots/$id" ro) == ro=true ]]
 sync -f "$work"
 mkdir -p /boot/titan/snapshots
 sync -f "$stage"
 mv -T -- "$stage" "/boot/titan/snapshots/$id"
 stage=''
 sync -f /boot
 # Preserve any captured snapshot on menu failure; never delete user recovery data.
 "$root/scripts/titan-boot" refresh >&2 || { titan_boot_fail "Snapshot $id retained; fix refresh before using the entry"; exit 1; }
 cat "/boot/titan/snapshots/$id/manifest.json"
)
