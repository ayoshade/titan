"""Experimental dedicated-disk installer. Apply is confined to live QEMU VMs."""
import getpass
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from hardware import detect

ROOT = Path(__file__).resolve().parents[2]
FINGERPRINT = "2AD324F1003EA830989F51298A648F6B462B95C6"
TARGET = Path("/mnt/titan-target")
SUBVOLUMES = {"@": "/", "@home": "/home", "@log": "/var/log", "@pkg": "/var/cache/pacman/pkg"}


def run(*args, data=None, capture=False):
    return subprocess.run(args, input=data, text=True, check=True,
                          stdout=subprocess.PIPE if capture else None).stdout


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
    if os.geteuid() != 0 or not Path("/run/archiso/bootmnt").is_mount():
        raise ValueError("Apply requires root in the live ISO")
    if run("systemd-detect-virt", capture=True).strip() not in {"qemu", "kvm"}:
        raise ValueError("This experimental installer applies only in QEMU VMs")
    if not Path("/sys/firmware/efi").is_dir():
        raise ValueError("Boot the VM with UEFI firmware")
    if not installation["hardware"]["installer_supported"]:
        raise ValueError("This GPU needs a reviewed hardware profile")
    if args.vm_repo and not re.fullmatch(r"http://10\.0\.2\.2:[0-9]{2,5}/repo", args.vm_repo):
        raise ValueError("The development repository must be QEMU's host /repo URL")
    for tool in ["sfdisk", "wipefs", "mkfs.fat", "mkfs.btrfs", "pacstrap", "arch-chroot", "genfstab", "udevadm", "curl", "bsdtar", "vercmp", "blkid", "btrfs", "mount", "umount"]:
        if not shutil.which(tool):
            raise ValueError(f"Missing live installer tool: {tool}")
    if TARGET.exists():
        raise ValueError(f"{TARGET} already exists; inspect the previous attempt before retrying")
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
    TARGET.mkdir()
    mounted = False
    try:
        run("wipefs", "--all", disk)
        run("sfdisk", disk, data="label: gpt\nsize=1GiB, type=U\ntype=L\n")
        run("udevadm", "settle")
        suffix = "p" if disk[-1].isdigit() else ""
        efi, root = disk + suffix + "1", disk + suffix + "2"
        run("mkfs.fat", "-F", "32", "-n", "TITAN_EFI", efi)
        run("mkfs.btrfs", "-f", "-L", "TITAN_ROOT", root)
        run("mount", root, str(TARGET)); mounted = True
        for name in SUBVOLUMES:
            run("btrfs", "subvolume", "create", str(TARGET / name))
        run("umount", str(TARGET)); mounted = False
        run("mount", "-o", "noatime,compress=zstd,subvol=@", root, str(TARGET)); mounted = True
        for name, path in SUBVOLUMES.items():
            if path == "/":
                continue
            destination = TARGET / path.lstrip("/")
            destination.mkdir(parents=True)
            run("mount", "-o", f"noatime,compress=zstd,subvol={name}", root, str(destination))
        (TARGET / "boot").mkdir()
        run("mount", efi, str(TARGET / "boot"))
        print("Installing Arch base and hardware packages…", flush=True)
        run("pacstrap", "-K", str(TARGET), *installation["packages"])
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
        chroot("pacman", "-Syu", "--needed", "--noconfirm", "titan-desktop")
        chroot("/usr/share/titan/scripts/install-login", "--no-packages")
        chroot("systemctl", "enable", "NetworkManager", "bluetooth", "power-profiles-daemon")
        # Keep the hardware plan for diagnostics; no machine-specific config
        # is written into the user's overrides or shipped defaults.
        write("/etc/titan/install-plan.json", json.dumps(installation, indent=2) + "\n")
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
        chroot("mkinitcpio", "-P")
        print("Titan installed. Shut down this VM, detach the ISO and boot its virtual disk. No reboot was requested.")
    finally:
        password = None
        if mounted:
            run("umount", "--recursive", str(TARGET))
        # Keep the directory on failure as an explicit retry/recovery marker.
