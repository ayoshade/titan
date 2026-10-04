"""Experimental dedicated-disk installer. Apply is confined to live QEMU VMs."""
import getpass
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import sys
from datetime import datetime, timezone

from hardware import detect

ROOT = Path(__file__).resolve().parents[2]
FINGERPRINT = "2AD324F1003EA830989F51298A648F6B462B95C6"
TARGET = Path("/mnt/titan-target")
SUBVOLUMES = {"@": "/", "@home": "/home", "@log": "/var/log", "@pkg": "/var/cache/pacman/pkg"}
STATE = Path("/run/titan-installer")
LOCK_FD = None


def run(*args, data=None, capture=False):
    return subprocess.run(args, input=data, text=True, check=True,
                          pass_fds=() if LOCK_FD is None else (LOCK_FD,),
                          stdout=subprocess.PIPE if capture else None).stdout


def require_live_vm():
    if os.geteuid() != 0 or not Path("/run/archiso/bootmnt").is_mount():
        raise ValueError("Apply/recovery requires root in the live ISO")
    if run("systemd-detect-virt", capture=True).strip() not in {"qemu", "kvm"}:
        raise ValueError("This experimental installer applies only in QEMU VMs")
    if not Path("/sys/firmware/efi").is_dir():
        raise ValueError("Boot the VM with UEFI firmware")


@contextmanager
def operation_lock():
    """Children retain the lock if their installer parent is forcibly killed."""
    global LOCK_FD
    if STATE.is_symlink():
        raise ValueError("Installer state directory must not be a symlink")
    STATE.mkdir(mode=0o700, exist_ok=True)
    fd = os.open(STATE / "lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError("An installer or recovery command is still running") from None
        LOCK_FD = fd
        yield
    finally:
        LOCK_FD = None
        os.close(fd)


def read_attempt():
    path = STATE / "attempt.json"
    if not path.exists():
        return None
    try:
        record = json.loads(path.read_text())
        if record["schema"] != 1 or record["target"] != str(TARGET):
            raise ValueError
        if record["status"] not in {"running", "failed", "installed", "recovered"}:
            raise ValueError
        if not isinstance(record["mounts"], list) or not isinstance(record["disk"], dict):
            raise ValueError
        if not isinstance(record["boot_id"], str) or not isinstance(record["step"], str):
            raise ValueError
        disk = record["disk"]
        if not isinstance(disk["name"], str) or not disk["name"].startswith("/dev/") \
                or type(disk["identity"]) is not int or type(disk["size"]) is not int:
            raise ValueError
        for mount in record["mounts"]:
            if not all(isinstance(mount[key], str) and mount[key]
                       for key in ["target", "device", "maj:min", "uuid", "fsroot"]):
                raise ValueError
        return record
    except (ValueError, KeyError, TypeError):
        raise ValueError("Invalid installer recovery record; inspect it manually") from None


def checkpoint(record, **changes):
    record.update(changes, updated_at=datetime.now(timezone.utc).isoformat())
    # Never record command input, account passwords or subprocess output.
    with tempfile.NamedTemporaryFile(mode="w", dir=STATE, delete=False) as output:
        temporary = Path(output.name)
        try:
            json.dump(record, output, indent=2)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
            os.replace(temporary, STATE / "attempt.json")
        finally:
            temporary.unlink(missing_ok=True)


def failure_checkpoint(record, **changes):
    try:
        checkpoint(record, **changes)
    except OSError:
        # A full/broken live state directory must not mask the actual failure.
        print("Could not update the recovery journal; inspect the target manually.", file=sys.stderr)


def target_mounts():
    mounts = json.loads(run("findmnt", "--json", "--list", "--output",
                            "TARGET,SOURCE,UUID,FSROOT,MAJ:MIN", capture=True))["filesystems"]
    return [m for m in mounts if m["target"] == str(TARGET)
            or m["target"].startswith(str(TARGET) + "/")]


def status():
    """Inspection creates no files and takes no exclusive lock."""
    busy = False
    try:
        fd = os.open(STATE / "lock", os.O_RDONLY | os.O_NOFOLLOW)
    except FileNotFoundError:
        pass
    else:
        try:
            try:
                fcntl.flock(fd, fcntl.LOCK_SH | fcntl.LOCK_NB)
            except BlockingIOError:
                busy = True
        finally:
            os.close(fd)
    return {"schema": 1, "attempt": read_attempt(), "busy": busy,
            "target_exists": TARGET.exists(), "live_mounts": target_mounts()}


def mount_target(record, device, destination, *options):
    identity = os.stat(device).st_rdev
    subvolume = re.search(r"(?:^|,)subvol=([^,]+)", ",".join(options))
    mount = {"target": str(destination), "device": device,
             "maj:min": f"{os.major(identity)}:{os.minor(identity)}",
             "fsroot": "/" + subvolume[1].lstrip("/") if subvolume else "/",
             "uuid": run("blkid", "-s", "UUID", "-o", "value", device, capture=True).strip()}
    record["mounts"] = [m for m in record["mounts"] if m["target"] != str(destination)] + [mount]
    # Record intent before mount, covering a kill between mount and return.
    checkpoint(record)
    run("mount", *options, device, str(destination))


def recovery_mounts(record):
    if record["boot_id"] != Path("/proc/sys/kernel/random/boot_id").read_text().strip():
        raise ValueError("Recovery record belongs to a different live boot")
    disk = record["disk"]
    matches = [d for d in block_devices() if d["name"] == disk["name"] and d["type"] == "disk"]
    if len(matches) != 1 or matches[0]["ro"] or matches[0]["size"] != disk["size"] \
            or os.stat(disk["name"]).st_rdev != disk["identity"]:
        raise ValueError("The recorded recovery disk changed; inspect manually")
    suffix = "p" if disk["name"][-1].isdigit() else ""
    devices = {disk["name"] + suffix + str(i) for i in [1, 2]}
    allowed_paths = {str(TARGET), *(str(TARGET / p.lstrip("/"))
                      for p in ["/home", "/var/log", "/var/cache/pacman/pkg", "/boot"])}
    expected = {}
    for mount in record["mounts"]:
        if mount["target"] not in allowed_paths or mount["device"] not in devices:
            raise ValueError("Recovery record contains an unexpected mount")
        identity = os.stat(mount["device"]).st_rdev
        if mount["maj:min"] != f"{os.major(identity)}:{os.minor(identity)}" or \
                mount["uuid"] != run("blkid", "-s", "UUID", "-o", "value",
                                     mount["device"], capture=True).strip():
            raise ValueError("A recorded recovery filesystem changed; inspect manually")
        expected[mount["target"]] = mount
    mounts = target_mounts()
    for mount in mounts:
        owner = expected.get(mount["target"])
        # Btrfs reports an anonymous 0:N mount device; match the underlying
        # source, filesystem UUID and subvolume root instead of that number.
        source = mount.get("source", "").split("[", 1)[0]
        if owner is None or str(Path(source).resolve()) != owner["device"] \
                or mount.get("uuid") != owner["uuid"] or mount.get("fsroot") != owner["fsroot"]:
            raise ValueError("Unrecorded or foreign mount below the installer target; inspect manually")
    for part in descendants(matches[0]):
        if any(p and p not in expected for p in part.get("mountpoints", [])):
            raise ValueError("Recovery disk is mounted outside the recorded target or active swap")
        holders = Path("/sys/class/block") / Path(part["name"]).name / "holders"
        if holders.exists() and any(holders.iterdir()):
            raise ValueError("Recovery disk has device-mapper/RAID holders")
    if TARGET.is_symlink():
        raise ValueError("Installer target must not be a symlink")
    return mounts


def release_target(record):
    mounts = recovery_mounts(record)
    if mounts:
        # No lazy/forced unmount: busy mounts leave the recovery marker intact.
        run("umount", "--recursive", str(TARGET))
    if target_mounts():
        raise ValueError("Installer target still contains mounts")
    if TARGET.exists():
        TARGET.rmdir()  # Refuses nonempty directories; never deletes target data.


def recover(args):
    require_live_vm()
    with operation_lock():
        record = read_attempt()
        if record is None or record["status"] not in {"running", "failed"}:
            raise ValueError("There is no incomplete installation to recover")
        if not args.disk or str(Path(args.disk).resolve()) != record["disk"]["name"]:
            raise ValueError("Recovery requires --disk matching the recorded installation")
        if not os.isatty(0):
            raise ValueError("Recovery requires an interactive terminal")
        recovery_mounts(record)
        disk = record["disk"]["name"]
        print(f"Release the verified installer mounts on {disk} and clear the retry marker.\n"
              "The partial disk contents will remain. A new --apply requires a separate erase confirmation.")
        if input(f"Type RECOVER {disk} to continue: ") != f"RECOVER {disk}":
            raise ValueError("Recovery cancelled; nothing was changed")
        release_target(record)  # Recheck after confirmation, immediately before unmount.
        checkpoint(record, status="recovered", cleanup_error=None)
        print("Recovery complete. Inspect the partial disk or run a new installation with --apply.")


def block_devices():
    return json.loads(run("lsblk", "--json", "--bytes", "--paths", "--output",
                          "NAME,TYPE,SIZE,RO,MODEL,MOUNTPOINTS", capture=True))["blockdevices"]


def descendants(device):
    yield device
    for child in device.get("children", []):
        yield from descendants(child)


def check_disk(name, devices=None):
    path = str(Path(name).resolve())
    devices = block_devices() if devices is None else devices
    matches = [d for d in devices if d["name"] == path and d["type"] == "disk"]
    if len(matches) != 1:
        raise ValueError("Select a whole disk, not a partition, loop device or mapper")
    disk = matches[0]
    if disk["ro"] or int(disk["size"]) < 32 * 1024**3:
        raise ValueError("The disk must be writable and at least 32 GiB")
    for part in descendants(disk):
        if any(part.get("mountpoints") or []):
            raise ValueError(f"Disk is in use: {part['name']} is mounted or active swap")
        holders = Path("/sys/class/block") / Path(part["name"]).name / "holders"
        if holders.exists() and any(holders.iterdir()):
            raise ValueError(f"Disk is in use: {part['name']} has device-mapper/RAID holders")
    return disk


def plan(args):
    if not re.fullmatch(r"[a-z_][a-z0-9_-]{0,30}", args.user) or args.user in {"root", "greeter", "nobody"}:
        raise ValueError("Use a normal lowercase account name (not root/greeter/nobody)")
    if not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", args.hostname):
        raise ValueError("Use a lowercase hostname of 1–63 letters, digits or hyphens")
    zone = Path("/usr/share/zoneinfo") / args.timezone
    if not zone.is_file() or ".." in Path(args.timezone).parts or Path(args.timezone).is_absolute():
        raise ValueError("Select a timezone from /usr/share/zoneinfo")
    disk = check_disk(args.disk)
    hardware = detect()
    packages = (ROOT / "installation/packages.txt").read_text().split()
    return {"schema": 1, "experimental": True, "apply_scope": "QEMU live VM only",
            "disk": {key: disk[key] for key in ["name", "size", "model"]},
            "firmware": "UEFI", "partition_table": "GPT", "efi_size_mib": 1024,
            "filesystem": "btrfs", "encryption": False, "subvolumes": SUBVOLUMES,
            "user": args.user, "hostname": args.hostname, "timezone": args.timezone,
            "hardware": hardware, "packages": sorted(set(packages + hardware["packages"])),
            "desktop": "titan-desktop", "repository": args.vm_repo or
            "https://github.com/ayoshade/titan/releases/download/repo-stable"}


def chroot(*args, **kwargs):
    return run("arch-chroot", str(TARGET), *args, **kwargs)


def write(path, text, mode=0o644):
    destination = TARGET / path.lstrip("/")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(text)
    destination.chmod(mode)


def apply(args, installation):
    # No destructive path is available from the daily desktop, or on real
    # hardware, until the experimental installer has had a wider review.
    require_live_vm()
    if not installation["hardware"]["installer_supported"]:
        raise ValueError("This GPU needs a reviewed hardware profile")
    if args.vm_repo and not re.fullmatch(r"http://10\.0\.2\.2:[0-9]{2,5}/repo", args.vm_repo):
        raise ValueError("The development repository must be QEMU's host /repo URL")
    for tool in ["sfdisk", "wipefs", "mkfs.fat", "mkfs.btrfs", "pacstrap", "arch-chroot", "genfstab", "udevadm", "curl", "bsdtar", "vercmp", "blkid", "btrfs", "mount", "umount", "findmnt"]:
        if not shutil.which(tool):
            raise ValueError(f"Missing live installer tool: {tool}")
    with operation_lock():
        _apply(args, installation)


def _apply(args, installation):
    previous = read_attempt()
    if previous and previous["status"] in {"running", "failed"}:
        raise ValueError("An incomplete installation is recorded; use --status, then --recover first")
    if TARGET.exists():
        raise ValueError(f"{TARGET} already exists; inspect the previous attempt before retrying")
    if TARGET.is_symlink():
        raise ValueError("Installer target must not be a symlink")
    if not os.isatty(0):
        raise ValueError("Apply requires an interactive terminal")
    # Check release compatibility before erasing, including the signed public
    # channel. Package authenticity is still enforced by pacman below.
    with tempfile.TemporaryDirectory(prefix="titan-preflight-") as folder:
        database = str(Path(folder) / "titan.db")
        run("curl", "--fail", "--silent", "--show-error", "--max-time", "20",
            "--output", database, installation["repository"] + "/titan.db")
        entries = run("bsdtar", "-tf", database, capture=True).splitlines()
        desc = next((e for e in entries if re.fullmatch(r"titan-[0-9][^/]*/desc", e)), None)
        if desc is None:
            raise ValueError("Repository does not contain Titan")
        text = run("bsdtar", "-xOf", database, desc, capture=True)
        found = re.search(r"%VERSION%\n([^\n]+)", text)
        required = (ROOT / "version").read_text().strip()
        if found is None or run("vercmp", found[1], required, capture=True).strip().startswith("-"):
            raise ValueError(f"Repository needs Titan {required} or newer; use the local VM test repository until it is published")
    key = ROOT / "keys/titan-packager.asc"
    if not args.vm_repo:
        fingerprints = run("gpg", "--batch", "--with-colons", "--show-keys", str(key), capture=True)
        if FINGERPRINT not in fingerprints:
            raise ValueError("Packager key fingerprint does not match Titan")
    disk = installation["disk"]["name"]
    identity = os.stat(disk).st_rdev
    print(f"\nAll data on {disk} will be erased. This VM prototype uses an unencrypted root.")
    if input(f"Type ERASE {disk} to continue: ") != f"ERASE {disk}":
        raise ValueError("Installation cancelled; no disk was changed")
    password = getpass.getpass("New account password: ")
    if not password or "\n" in password or password != getpass.getpass("Repeat password: "):
        raise ValueError("Passwords must match and be nonempty; no disk was changed")
    # Re-check immediately before the first write; never trust a stale preview.
    check_disk(disk)
    if os.stat(disk).st_rdev != identity:
        raise ValueError("The selected device changed since confirmation")
    record = {"schema": 1, "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
              "target": str(TARGET), "disk": dict(installation["disk"], identity=identity),
              "status": "running", "step": "partitioning", "mounts": [],
              "cleanup_error": None}
    checkpoint(record)
    try:
        TARGET.mkdir()
        run("wipefs", "--all", disk)
        run("sfdisk", disk, data="label: gpt\nsize=1GiB, type=U\ntype=L\n")
        run("udevadm", "settle")
        suffix = "p" if disk[-1].isdigit() else ""
        efi, root = disk + suffix + "1", disk + suffix + "2"
        checkpoint(record, step="filesystems")
        run("mkfs.fat", "-F", "32", "-n", "TITAN_EFI", efi)
        run("mkfs.btrfs", "-f", "-L", "TITAN_ROOT", root)
        mount_target(record, root, TARGET)
        for name in SUBVOLUMES:
            run("btrfs", "subvolume", "create", str(TARGET / name))
        run("umount", str(TARGET))
        mount_target(record, root, TARGET, "-o", "noatime,compress=zstd,subvol=@")
        for name, path in SUBVOLUMES.items():
            if path == "/":
                continue
            destination = TARGET / path.lstrip("/")
            destination.mkdir(parents=True)
            mount_target(record, root, destination, "-o", f"noatime,compress=zstd,subvol={name}")
        (TARGET / "boot").mkdir()
        mount_target(record, efi, TARGET / "boot")
        checkpoint(record, step="base-packages")
        print("Installing Arch base and hardware packages…", flush=True)
        run("pacstrap", "-K", str(TARGET), *installation["packages"])
        checkpoint(record, step="system-configuration")
        write("/etc/fstab", run("genfstab", "-U", str(TARGET), capture=True))
        write("/etc/hostname", args.hostname + "\n")
        write("/etc/hosts", f"127.0.0.1 localhost\n::1 localhost\n127.0.1.1 {args.hostname}\n")
        write("/etc/locale.gen", "en_US.UTF-8 UTF-8\n")
        write("/etc/locale.conf", "LANG=en_US.UTF-8\n")
        write("/etc/vconsole.conf", "KEYMAP=us\n")
        (TARGET / "etc/localtime").symlink_to("/usr/share/zoneinfo/" + args.timezone)
        chroot("locale-gen")
        chroot("useradd", "-m", "-G", "wheel", "-s", "/bin/bash", args.user)
        chroot("chpasswd", data=args.user + ":" + password + "\n")
        password = None
        chroot("passwd", "-l", "root")
        write("/etc/sudoers.d/10-titan-wheel", "%wheel ALL=(ALL:ALL) ALL\n", 0o440)
        chroot("visudo", "-cf", "/etc/sudoers.d/10-titan-wheel")
        config = (TARGET / "etc/pacman.conf").read_text()
        if args.vm_repo:
            config += f"\n[titan]\nSigLevel = Optional TrustAll\nServer = {args.vm_repo}\n"
        else:
            write("/etc/pacman.d/titan-packager.asc", key.read_text())
            chroot("pacman-key", "--init")
            chroot("pacman-key", "--populate", "archlinux")
            chroot("pacman-key", "--add", "/etc/pacman.d/titan-packager.asc")
            chroot("pacman-key", "--lsign-key", FINGERPRINT)
            config += f"\n[titan]\nServer = {installation['repository']}\n"
        write("/etc/pacman.conf", config)
        checkpoint(record, step="desktop-packages")
        chroot("pacman", "-Syu", "--needed", "--noconfirm", "titan-desktop")
        checkpoint(record, step="services")
        chroot("/usr/share/titan/scripts/install-login", "--no-packages")
        chroot("systemctl", "enable", "NetworkManager", "bluetooth", "power-profiles-daemon")
        # Keep the hardware plan for diagnostics; no machine-specific config
        # is written into the user's overrides or shipped defaults.
        write("/etc/titan/install-plan.json", json.dumps(installation, indent=2) + "\n")
        checkpoint(record, step="bootloader")
        chroot("bootctl", "--esp-path=/boot", "--no-variables", "install")
        uuid = run("blkid", "-s", "UUID", "-o", "value", root, capture=True).strip()
        write("/boot/loader/loader.conf", "default titan.conf\ntimeout 3\nconsole-mode keep\n")
        write("/boot/loader/entries/titan.conf", "title Titan\nlinux /vmlinuz-linux\n"
              f"initrd /initramfs-linux.img\noptions root=UUID={uuid} rw rootflags=subvol=@ quiet splash plymouth.ignore-serial-consoles\n")
        shutil.copytree(TARGET / "usr/share/titan/system/plymouth/titan",
                        TARGET / "usr/share/plymouth/themes/titan")
        chroot("plymouth-set-default-theme", "titan")
        write("/etc/mkinitcpio.conf.d/titan.conf",
              "HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)\n")
        # microcode is embedded by mkinitcpio's hook; rebuild after all packages.
        checkpoint(record, step="initramfs")
        chroot("mkinitcpio", "-P")
        checkpoint(record, step="unmounting")
        release_target(record)
        checkpoint(record, status="installed", step="complete")
    except BaseException as error:
        # Keep the original failure, even when cleanup also fails. Store only
        # the exception class/exit code, never chpasswd input or command output.
        failure_checkpoint(record, status="failed", error_type=type(error).__name__,
                   exit_code=error.returncode if isinstance(error, subprocess.CalledProcessError) else None)
        # An interrupted subprocess may still be working (and retaining the
        # operation lock). Leave its mounts alone until explicit recovery.
        if not isinstance(error, KeyboardInterrupt):
            try:
                if recovery_mounts(record):
                    run("umount", "--recursive", str(TARGET))
            except (ValueError, OSError, subprocess.CalledProcessError) as cleanup_error:
                failure_checkpoint(record, cleanup_error=type(cleanup_error).__name__)
                print("Installer cleanup could not release the target; inspect --status before --recover.", file=sys.stderr)
        print(f"Installation stopped at {record['step']}. Inspect titan-install --status; "
              f"recover with titan-install --recover --disk {disk} before retrying.", file=sys.stderr)
        raise
    finally:
        password = None
    print("Titan installed. Shut down this VM, detach the ISO and boot its virtual disk. No reboot was requested.")
