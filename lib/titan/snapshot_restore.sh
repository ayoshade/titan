# Original offline recovery for dedicated-disk Titan Limine QEMU installations.
# Persistent journal and retained roots live at the Btrfs top level, outside @.
titan_restore_fail() { echo "titan snapshot: $*" >&2; return 1; }

titan_restore_live() {
 ((EUID == 0)) || { titan_restore_fail 'Restore inspection/apply requires root in the live ISO'; return 1; }
 mountpoint -q /run/archiso/bootmnt || { titan_restore_fail 'Restore requires the live ISO, never the installed root or preview'; return 1; }
 case $(systemd-detect-virt --vm) in qemu|kvm) ;; *) titan_restore_fail 'Restore is confined to QEMU VMs'; return 1 ;; esac
 [[ -d /sys/firmware/efi ]] || { titan_restore_fail 'Restore requires UEFI'; return 1; }
 [[ $(readlink /proc/self/ns/mnt) == "$(readlink /proc/1/ns/mnt)" ]] || { titan_restore_fail 'Use the live system mount namespace'; return 1; }
 titan_boot_path /run/titan-installer/lock || return
 mkdir -p /run/titan-installer
 chmod 700 /run/titan-installer
 exec 7>/run/titan-installer/lock
 flock -n 7 || { titan_restore_fail 'An installer or recovery operation is running'; return 1; }
}

titan_restore_disk() {
 local device=$1 tree part holders
 [[ $device == /dev/* && -b $device && ! -L $device ]] || { titan_restore_fail 'Select a canonical whole disk device'; return 1; }
 tree=$(lsblk -Jbp -o NAME,TYPE,SIZE,RO,FSTYPE,UUID,PARTTYPE,MOUNTPOINTS "$device") || return
 jq -e '
  .blockdevices | length == 1 and (.[0] |
  .type == "disk" and .ro == false and .size >= 34359738368 and
  (.children | length == 2 and all(.[]; .type == "part" and .ro == false and (.children // [] | length == 0))) and
  ([., .children[]] | all(.[]; (.mountpoints // [] | all(.[]; . == null)))))' <<<"$tree" >/dev/null || {
  titan_restore_fail 'Disk must be unused, writable, dedicated and have exactly two partitions (no mounts/swap)'; return 1;
 }
 for part in $(jq -r '.blockdevices[0] | .name, .children[].name' <<<"$tree"); do
  holders=/sys/class/block/${part##*/}/holders
  [[ -d $holders && -z $(ls -A "$holders") ]] || { titan_restore_fail 'Disk has block-device holders'; return 1; }
 done
 restore_root_device=$(jq -er '.blockdevices[0].children[] | select(.fstype == "btrfs" and .parttype == "0fc63daf-8483-4772-8e79-3d69d8477de4") | .name' <<<"$tree") || return
 restore_esp_device=$(jq -er '.blockdevices[0].children[] | select(.fstype == "vfat" and .parttype == "c12a7328-f81f-11d2-ba4b-00a0c93ec93b") | .name' <<<"$tree") || return
 restore_uuid=$(blkid -s UUID -o value "$restore_root_device") || return
 restore_esp_uuid=$(blkid -s UUID -o value "$restore_esp_device") || return
 [[ $restore_uuid =~ ^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$ && $restore_esp_uuid =~ ^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$ ]] || return 1
 restore_identity="$(stat -c %t:%T "$device"):$(jq -r '.blockdevices[0].size' <<<"$tree"):$restore_uuid:$restore_esp_uuid"
 # Refuse multi-device Btrfs even if its other devices are currently unmounted.
 btrfs filesystem show --raw "$restore_root_device" | grep -q 'Total devices 1 ' || { titan_restore_fail 'Only single-device Btrfs roots are supported'; return 1; }
}

titan_restore_mount() {
 local mode=$1
 mount -t btrfs -o "subvolid=5,$mode" "$restore_root_device" "$restore_top"
 mount -t vfat -o "${mode%%,*}" "$restore_esp_device" "$restore_esp"
}

titan_restore_owned_mounts() {
 local table tree part
 table=$(findmnt --json --list -o TARGET,UUID,FSTYPE,FSROOT)
 jq -e --arg uuid "$restore_uuid" --arg esp "$restore_esp_uuid" --arg top "$restore_top" --arg boot "$restore_esp" '
  [.filesystems[] | select(.uuid == $uuid or .uuid == $esp)] |
  length == 2 and all(.[];
   (.uuid == $uuid and .target == $top and .fstype == "btrfs" and .fsroot == "/") or
   (.uuid == $esp and .target == $boot and .fstype == "vfat" and .fsroot == "/"))' <<<"$table" >/dev/null || {
  titan_restore_fail 'Target filesystems are mounted outside the owned recovery paths'; return 1;
 }
 tree=$(lsblk -Jbp -o NAME,TYPE,RO,MOUNTPOINTS "$restore_root_device" "$restore_esp_device")
 jq -e --arg top "$restore_top" --arg boot "$restore_esp" '[.blockdevices[] | .. | objects | select(has("name"))] | all(.[]; .ro == false and (.mountpoints // [] | all(.[]; . == null or . == $top or . == $boot)))' <<<"$tree" >/dev/null || {
  titan_restore_fail 'A target partition is read-only, mounted elsewhere or active swap'; return 1;
 }
 for part in "$restore_root_device" "$restore_esp_device"; do
  [[ -z $(ls -A "/sys/class/block/${part##*/}/holders") ]] || { titan_restore_fail 'Target partition acquired block-device holders'; return 1; }
 done
 [[ $(blkid -s UUID -o value "$restore_root_device") == "$restore_uuid" && $(blkid -s UUID -o value "$restore_esp_device") == "$restore_esp_uuid" ]] || return 1
}

titan_restore_subid() {
 local path=$1
 [[ -d $path && ! -L $path ]] || return 1
 btrfs subvolume show "$path" >/dev/null || return
 btrfs inspect-internal rootid "$path"
}

titan_restore_hash() { local hash; hash=$(sha256sum -- "$1") || return; printf '%s\n' "${hash%% *}"; }

titan_restore_source() {
 local id=$1 plan fstab target spec options fstype expected snapshot=$restore_top/@titan-snapshots/$1
 titan_snapshot_manifest "$restore_esp/titan/snapshots/$id" "$restore_uuid" || return
 titan_boot_path "$snapshot/etc/titan/install-plan.json" || return
 titan_boot_path "$snapshot/etc/fstab" || return
 [[ $(btrfs property get -ts "$snapshot" ro) == ro=true ]] || { titan_restore_fail 'Source snapshot must remain read-only'; return 1; }
 restore_source_id=$(titan_restore_subid "$snapshot") || return
 plan=$snapshot/etc/titan/install-plan.json
 jq -e --arg uuid "$restore_uuid" '.schema == 1 and .root_uuid == $uuid and .bootloader == "limine" and .apply_scope == "QEMU live VM only" and .filesystem == "btrfs" and .encryption == false and .subvolumes == {"@":"/","@home":"/home","@log":"/var/log","@pkg":"/var/cache/pacman/pkg"}' "$plan" >/dev/null || {
  titan_restore_fail 'Snapshot does not contain a compatible Titan installation plan'; return 1;
 }
 # The fstab must describe this same root and ESP, plus the separated volumes.
 fstab=$snapshot/etc/fstab
 for target in / /home /var/log /var/cache/pacman/pkg /boot; do
  spec=$(findmnt --fstab --tab-file "$fstab" -nr -o SOURCE --target "$target") || return
  fstype=$(findmnt --fstab --tab-file "$fstab" -nr -o FSTYPE --target "$target") || return
  if [[ $target == /boot ]]; then
   [[ $spec == "UUID=$restore_esp_uuid" && $fstype == vfat ]] || { titan_restore_fail 'Snapshot fstab does not match the ESP'; return 1; }
  else
   options=$(findmnt --fstab --tab-file "$fstab" -nr -o OPTIONS --target "$target") || return
   case $target in /) expected=@ ;; /home) expected=@home ;; /var/log) expected=@log ;; /var/cache/pacman/pkg) expected=@pkg ;; esac
   [[ $spec == "UUID=$restore_uuid" && $fstype == btrfs && ",$options," != *',subvolid='* &&
      ( ",$options," == *",subvol=/$expected,"* || ",$options," == *",subvol=$expected,"* ) ]] || {
    titan_restore_fail "Snapshot fstab must select $expected by name for $target"; return 1;
   }
  fi
 done
 local name version module
 name=$(jq -r '.kernel.name' "$restore_esp/titan/snapshots/$id/manifest.json")
 version=$(jq -r '.kernel.version' "$restore_esp/titan/snapshots/$id/manifest.json")
 module=$snapshot/usr/lib/modules/$version/vmlinuz
 titan_boot_path "$module" || return
 cmp -s "$module" "$restore_esp/titan/snapshots/$id/vmlinuz" || { titan_restore_fail 'Snapshot module tree and saved kernel differ'; return 1; }
 [[ $(cat "$snapshot/usr/lib/modules/$version/pkgbase") == "$name" && ! -e $snapshot/var/lib/pacman/db.lck ]] || {
  titan_restore_fail 'Snapshot kernel identity or package lock is invalid'; return 1;
 }
 titan_boot_path "$snapshot/etc/titan/limine.conf" || return
 titan_boot_path "$snapshot/usr/share/limine/BOOTX64.EFI" || return
 for target in @home @log @pkg; do titan_restore_subid "$restore_top/$target" >/dev/null || return; done
 titan_snapshot_render "$restore_uuid" "$restore_esp" >/dev/null || return
}

titan_restore_read() {
 titan_boot_path "$restore_journal" || return
 jq -e --arg uuid "$restore_uuid" --arg esp "$restore_esp_uuid" --arg identity "$restore_identity" '
  .schema == 1 and .root_uuid == $uuid and .esp_uuid == $esp and .disk_identity == $identity and
  (.snapshot | type == "string" and test("^[0-9]{8}T[0-9]{6}Z-[a-zA-Z0-9]{6}$")) and
  (.transaction | type == "string" and test("^[0-9]{8}T[0-9]{6}Z-[a-zA-Z0-9]{6}-[a-f0-9]{8}$")) and
  (.old_id | type == "number" and . > 255) and (.source_id | type == "number" and . > 255) and
  (.new_id == null or (.new_id | type == "number" and . > 255)) and
  (.phase == "preparing" or .new_id != null) and .source_id != .old_id and
  (.new_id == null or (.new_id != .old_id and .new_id != .source_id)) and
  (.phase | IN("preparing","staged","root-saved","root-installed","boot-installed","complete")) and
  (.outputs | type == "array" and length >= 2 and all(.[];
   (.path | type == "string" and test("^(vmlinuz-linux(-(lts|zen|hardened))?|initramfs-linux(-(lts|zen|hardened))?(-fallback)?[.]img|limine[.]conf|EFI/BOOT/BOOTX64[.]EFI)$")) and
   (.before == null or (.before | type == "string" and test("^[a-f0-9]{64}$"))) and
   (.after == null or (.after | type == "string" and test("^[a-f0-9]{64}$"))))) and
  ([.outputs[].path] | length == (unique | length))' "$restore_journal" >/dev/null || { titan_restore_fail 'Invalid restore journal or changed disk identity'; return 1; }
 restore_record=$(cat "$restore_journal")
 restore_id=$(jq -r '.snapshot' <<<"$restore_record")
 restore_txn=$(jq -r '.transaction' <<<"$restore_record")
 [[ $restore_txn == "$restore_id"-* ]] || return 1
 restore_stage=$restore_esp/titan/restores/$restore_txn
 restore_saved=$restore_top/@titan-before-$restore_txn
 restore_new=$restore_top/@titan-restore-$restore_txn
}

titan_restore_write() {
 local temporary=$restore_journal.tmp
 titan_boot_path "$temporary"
 printf '%s\n' "$restore_record" >"$temporary"
 sync -f "$temporary"
 mv -T "$temporary" "$restore_journal"
 sync -f "$restore_top"
}

titan_restore_phase() {
 restore_record=$(jq --arg phase "$1" '.phase = $phase' <<<"$restore_record")
 titan_restore_write
}

titan_restore_prepare() {
 local snapshot=$restore_top/@titan-snapshots/$restore_id name path before expected old_id new_id parent
 old_id=$(jq -r '.old_id' <<<"$restore_record")
 [[ $(titan_restore_subid "$restore_top/@") == "$old_id" && ! -e $restore_saved && ! -L $restore_saved ]] || { titan_restore_fail 'Original root changed before staging'; return 1; }
 name=$(jq -r '.kernel.name' "$restore_esp/titan/snapshots/$restore_id/manifest.json")
 titan_boot_path "$restore_stage/new/.check"
 titan_boot_path "$restore_stage/before/.check"
 while IFS= read -r path; do titan_boot_path "$restore_stage/new/$path"; done < <(jq -r '.outputs[].path' <<<"$restore_record")
 mkdir -p "$restore_stage"/{new/EFI/BOOT,before/EFI/BOOT}
 # Save each old output before root renames. An interrupted copy can be repeated
 # only while the original file still has the journal's recorded hash.
 while IFS= read -r path; do
  before=$(jq -r --arg path "$path" '.outputs[] | select(.path == $path) | .before' <<<"$restore_record")
  titan_boot_path "$restore_esp/$path"; titan_boot_path "$restore_stage/before/$path"
  if [[ $before != null ]]; then
   [[ -f $restore_esp/$path && $(titan_restore_hash "$restore_esp/$path") == "$before" ]] || { titan_restore_fail "Original boot file changed: $path"; return 1; }
   cp -- "$restore_esp/$path" "$restore_stage/before/$path"
  else
   [[ ! -e $restore_esp/$path ]] || { titan_restore_fail "Unexpected boot file: $path"; return 1; }
  fi
 done < <(jq -r '.outputs[].path' <<<"$restore_record")
 cp "$restore_esp/titan/snapshots/$restore_id/vmlinuz" "$restore_stage/new/vmlinuz-$name"
 cp "$restore_esp/titan/snapshots/$restore_id/initramfs.img" "$restore_stage/new/initramfs-$name.img"
 cp "$snapshot/usr/share/limine/BOOTX64.EFI" "$restore_stage/new/EFI/BOOT/BOOTX64.EFI"
 titan_boot_render "$restore_uuid" "$restore_stage/new" "$snapshot/etc/titan/limine.conf" >"$restore_stage/new/limine.conf"
 titan_snapshot_render "$restore_uuid" "$restore_esp" >>"$restore_stage/new/limine.conf"
 while IFS= read -r path; do
  expected=null
  [[ ! -f $restore_stage/new/$path ]] || expected=$(titan_restore_hash "$restore_stage/new/$path")
  restore_record=$(jq --arg path "$path" --arg hash "$expected" '(.outputs[] | select(.path == $path) | .after) = (if $hash == "null" then null else $hash end)' <<<"$restore_record")
 done < <(jq -r '.outputs[].path' <<<"$restore_record")
 sync -f "$restore_esp"
 titan_boot_path "$restore_new/.check"
 if [[ ! -e $restore_new ]]; then btrfs subvolume snapshot "$snapshot" "$restore_new" >&2; fi
 new_id=$(titan_restore_subid "$restore_new")
 # A kill after snapshot creation but before recording its ID is recoverable;
 # require its actual parent UUID to be that of the immutable source snapshot.
 parent=$(btrfs subvolume show "$snapshot" | awk '$1 == "UUID:" {print $2}')
 [[ $(btrfs subvolume show "$restore_new" | awk '$1 == "Parent" && $2 == "UUID:" {print $3}') == "$parent" && $(btrfs property get -ts "$restore_new" ro) == ro=false ]] || {
  titan_restore_fail 'Staged restore root does not match the source snapshot'; return 1;
 }
 restore_record=$(jq --argjson id "$new_id" '.new_id = $id' <<<"$restore_record")
 titan_restore_phase staged
}

titan_restore_apply() {
 local old_id new_id actual before after path temporary
 titan_restore_owned_mounts
 [[ $(jq -r '.phase' <<<"$restore_record") != preparing ]] || titan_restore_prepare
 old_id=$(jq -r '.old_id' <<<"$restore_record"); new_id=$(jq -r '.new_id' <<<"$restore_record")
 # Validate every staged output and retained backup before changing root names.
 while IFS= read -r path; do
  before=$(jq -r --arg path "$path" '.outputs[] | select(.path == $path) | .before' <<<"$restore_record")
  after=$(jq -r --arg path "$path" '.outputs[] | select(.path == $path) | .after' <<<"$restore_record")
  titan_boot_path "$restore_stage/before/$path"; titan_boot_path "$restore_stage/new/$path"
  titan_boot_path "$restore_esp/$path"
  [[ $before == null || $(titan_restore_hash "$restore_stage/before/$path") == "$before" ]] || { titan_restore_fail 'Retained boot backup changed'; return 1; }
  [[ $after == null || $(titan_restore_hash "$restore_stage/new/$path") == "$after" ]] || { titan_restore_fail 'Staged boot output changed'; return 1; }
  actual=null
  [[ ! -f $restore_esp/$path ]] || actual=$(titan_restore_hash "$restore_esp/$path")
  [[ $actual == "$before" || $actual == "$after" ]] || { titan_restore_fail "Boot destination changed: $path"; return 1; }
 done < <(jq -r '.outputs[].path' <<<"$restore_record")
 titan_restore_owned_mounts
 # Inspect IDs rather than trusting the last checkpoint: a rename can finish
 # immediately before power loss, before the next journal update is durable.
 if [[ ! -e $restore_saved && ! -L $restore_saved ]]; then
  [[ $(titan_restore_subid "$restore_top/@") == "$old_id" && $(titan_restore_subid "$restore_new") == "$new_id" ]] || { titan_restore_fail 'Root identities changed'; return 1; }
  mv -T "$restore_top/@" "$restore_saved"
  sync -f "$restore_top"
 fi
 [[ $(titan_restore_subid "$restore_saved") == "$old_id" ]] || { titan_restore_fail 'Retained original root changed'; return 1; }
 if [[ ! -e $restore_top/@ && ! -L $restore_top/@ ]]; then
  [[ $(titan_restore_subid "$restore_new") == "$new_id" ]] || return 1
  titan_restore_phase root-saved
  mv -T "$restore_new" "$restore_top/@"
  sync -f "$restore_top"
 fi
 [[ $(titan_restore_subid "$restore_top/@") == "$new_id" && ! -e $restore_new ]] || { titan_restore_fail 'Restored root identity changed'; return 1; }
 titan_restore_phase root-installed
 while IFS= read -r path; do
  before=$(jq -r --arg path "$path" '.outputs[] | select(.path == $path) | .before' <<<"$restore_record")
  after=$(jq -r --arg path "$path" '.outputs[] | select(.path == $path) | .after' <<<"$restore_record")
  titan_boot_path "$restore_esp/$path"; titan_boot_path "$restore_stage/before/$path"; titan_boot_path "$restore_stage/new/$path"
  [[ $before == null || $(titan_restore_hash "$restore_stage/before/$path") == "$before" ]] || { titan_restore_fail 'Retained boot backup changed'; return 1; }
  actual=null
  [[ ! -f $restore_esp/$path ]] || actual=$(titan_restore_hash "$restore_esp/$path")
  [[ $actual == "$before" || $actual == "$after" ]] || { titan_restore_fail "Boot destination changed: $path"; return 1; }
  titan_restore_owned_mounts
  if [[ $after == null ]]; then
   [[ ! -f $restore_esp/$path ]] || rm -- "$restore_esp/$path"
  else
   [[ $(titan_restore_hash "$restore_stage/new/$path") == "$after" ]] || { titan_restore_fail 'Staged boot output changed'; return 1; }
   mkdir -p "$(dirname -- "$restore_esp/$path")"
   temporary=${restore_esp}/${path}.titan-restore
   titan_boot_path "$temporary"
   cp -- "$restore_stage/new/$path" "$temporary"
   sync -f "$temporary"
   mv -T "$temporary" "$restore_esp/$path"
  fi
  sync -f "$restore_esp"
 done < <(jq -r '.outputs[].path' <<<"$restore_record")
 titan_restore_phase boot-installed
 titan_restore_phase complete
 cat "$restore_journal"
 echo "Restore complete. Original root retained as ${restore_saved##*/}; boot backups under /boot/titan/restores/$restore_txn. Boot the installed disk when ready." >&2
}

titan_snapshot_restore() (
 set -euo pipefail
 umask 077
 local action=$1 disk=$2 requested=${3:-} restore_work restore_top restore_esp restore_journal restore_record restore_id restore_txn restore_stage restore_saved restore_new
 local restore_root_device restore_esp_device restore_uuid restore_esp_uuid restore_identity restore_source_id baseline answer old_id path hash outputs='[]' name txn
 local -a paths
 titan_restore_live
 titan_restore_disk "$disk"
 baseline=$restore_identity
 restore_work=$(mktemp -d /run/titan-restore.XXXXXX)
 restore_top=$restore_work/root; restore_esp=$restore_work/esp
 mkdir "$restore_top" "$restore_esp"
 trap 'result=$?; for destination in "$restore_esp" "$restore_top"; do if mountpoint -q "$destination"; then umount "$destination" || result=1; fi; done; if ! mountpoint -q "$restore_top" && ! mountpoint -q "$restore_esp"; then rmdir "$restore_top" "$restore_esp" "$restore_work"; fi; exit "$result"' EXIT
 trap 'exit 130' INT TERM
 titan_restore_mount ro,rescue=nologreplay
 titan_restore_owned_mounts
 if [[ $action == inventory ]]; then
  titan_boot_path "$restore_esp/titan/snapshots/.check"
  local directory
  for directory in "$restore_esp"/titan/snapshots/*; do
   [[ -e $directory || -L $directory ]] || continue
   titan_snapshot_manifest "$directory" "$restore_uuid"
   cat "$directory/manifest.json"
  done | jq -s '{schema:1,experimental:true,snapshots:.,restore_supported:true,restore_scope:"live UEFI QEMU ISO only"}'
  exit 0
 fi
 restore_journal=$restore_top/titan-restore/journal.json
 titan_boot_path "$restore_journal"
 if [[ -f $restore_journal ]]; then titan_restore_read; fi
 if [[ $action == status ]]; then
  if [[ -f $restore_journal ]]; then cat "$restore_journal"; else printf '%s\n' '{"schema":1,"restore":null}'; fi
  exit 0
 fi
 if [[ $action == resume ]]; then
  [[ -f $restore_journal && $(jq -r '.phase' <<<"$restore_record") != complete ]] || { titan_restore_fail 'No interrupted restore to resume'; exit 1; }
  requested=$restore_id
 else
  [[ ! -f $restore_journal || $(jq -r '.phase' <<<"$restore_record") == complete ]] || { titan_restore_fail 'An interrupted restore exists; inspect restore-status and use restore-resume'; exit 1; }
 fi
 titan_restore_source "$requested"
 local source_before=$restore_source_id
 echo "Restore snapshot $requested on $disk. Retain the displaced root and boot files; preserve separate home/log/cache volumes. Interrupted restores require this live ISO again." >&2
 printf 'Type RESTORE %s %s to continue: ' "$requested" "$disk" >&2
 IFS= read -r answer || { titan_restore_fail 'Restore cancelled'; exit 1; }
 [[ $answer == "RESTORE $requested $disk" ]] || { titan_restore_fail 'Restore cancelled; no persistent data changed'; exit 1; }
 umount "$restore_esp"; umount "$restore_top"
 titan_restore_disk "$disk"
 [[ $restore_identity == "$baseline" ]] || { titan_restore_fail 'Disk changed during confirmation'; exit 1; }
 titan_restore_mount rw
 titan_restore_owned_mounts
 titan_restore_source "$requested"
 [[ $restore_source_id == "$source_before" ]] || { titan_restore_fail 'Source snapshot changed'; exit 1; }
 if [[ $action == resume ]]; then
  titan_restore_read
  [[ $restore_id == "$requested" && $(jq -r '.source_id' <<<"$restore_record") == "$restore_source_id" ]] || { titan_restore_fail 'Journal/source changed during confirmation'; exit 1; }
 else
  if [[ -f $restore_journal ]]; then
   titan_restore_read
   [[ $(jq -r '.phase' <<<"$restore_record") == complete ]] || exit 1
   titan_boot_path "$restore_top/titan-restore/$restore_txn.json"
   cp "$restore_journal" "$restore_top/titan-restore/$restore_txn.json"
  fi
  old_id=$(titan_restore_subid "$restore_top/@")
  titan_boot_path "$restore_esp/limine.conf"
  # Explicit offline restore can repair a missing/corrupt ordinary menu. Its
  # regular-file contents, if present, are retained like every other boot file.
  name=$(jq -r '.kernel.name' "$restore_esp/titan/snapshots/$requested/manifest.json")
  mapfile -t paths < <({ printf '%s\n' limine.conf EFI/BOOT/BOOTX64.EFI "vmlinuz-$name" "initramfs-$name.img"; for path in "$restore_esp"/vmlinuz-* "$restore_esp"/initramfs-*.img; do [[ ! -e $path && ! -L $path ]] || printf '%s\n' "${path##*/}"; done; } | sort -u)
  local needed=67108864 available
  for path in "${paths[@]}"; do
   [[ $path =~ ^(vmlinuz-linux(-(lts|zen|hardened))?|initramfs-linux(-(lts|zen|hardened))?(-fallback)?\.img|limine\.conf|EFI/BOOT/BOOTX64\.EFI)$ ]] || { titan_restore_fail "Unsupported boot output: $path"; exit 1; }
   titan_boot_path "$restore_esp/$path"
   hash=null
   if [[ -f $restore_esp/$path ]]; then hash=$(titan_restore_hash "$restore_esp/$path"); needed=$((needed + $(stat -c %s "$restore_esp/$path"))); fi
   outputs=$(jq --arg path "$path" --arg hash "$hash" '. + [{path:$path,before:(if $hash == "null" then null else $hash end),after:null}]' <<<"$outputs")
  done
  needed=$((needed + 2 * ( $(stat -c %s "$restore_esp/titan/snapshots/$requested/vmlinuz") + $(stat -c %s "$restore_esp/titan/snapshots/$requested/initramfs.img") + $(stat -c %s "$restore_top/@titan-snapshots/$requested/usr/share/limine/BOOTX64.EFI") )))
  available=$(df -B1 --output=avail "$restore_esp" | tail -1)
  ((available > needed)) || { titan_restore_fail 'Insufficient ESP space for retained boot backups and staged restore'; exit 1; }
  txn=$requested-$(cut -c1-8 /proc/sys/kernel/random/uuid)
  mkdir -p "$restore_top/titan-restore"; chmod 700 "$restore_top/titan-restore"
  restore_record=$(jq -n --arg id "$requested" --arg txn "$txn" --arg uuid "$restore_uuid" --arg esp "$restore_esp_uuid" --arg identity "$restore_identity" --argjson old "$old_id" --argjson source "$restore_source_id" --argjson outputs "$outputs" '{schema:1,snapshot:$id,transaction:$txn,root_uuid:$uuid,esp_uuid:$esp,disk_identity:$identity,old_id:$old,source_id:$source,new_id:null,phase:"preparing",outputs:$outputs}')
  titan_restore_write
  titan_restore_read
 fi
 titan_restore_apply
)
