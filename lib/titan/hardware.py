"""Read-only hardware inventory and conservative installer package selection."""
import json
from pathlib import Path
import platform

ROOT = Path(__file__).resolve().parents[2]
VENDORS = {"0x8086": "intel", "0x1002": "amd", "0x10de": "nvidia",
           "0x1af4": "virtual", "0x1234": "virtual", "0x15ad": "virtual"}


def read(path):
    try:
        return path.read_text().strip()
    except (OSError, UnicodeError):
        return ""


def detect(sysroot=Path("/")):
    cpu = {}
    for line in read(sysroot / "proc/cpuinfo").splitlines():
        key, _, value = line.partition(":")
        cpu.setdefault(key.strip(), value.strip())
    gpus = []
    for device in sorted((sysroot / "sys/bus/pci/devices").glob("*")):
        if not read(device / "class").startswith("0x03"):
            continue
        vendor = read(device / "vendor")
        driver = device / "driver"
        gpus.append({"pci": device.name, "vendor": VENDORS.get(vendor, "unknown"),
                     "vendor_id": vendor, "device_id": read(device / "device"),
                     "driver": driver.resolve().name if driver.is_symlink() else ""})
    batteries = [p.name for p in sorted((sysroot / "sys/class/power_supply").glob("*"))
                 if read(p / "type") == "Battery"]
    profiles = json.loads((ROOT / "system/hardware/profiles.json").read_text())
    packages = list(profiles["base"]) + profiles["cpu"].get(cpu.get("vendor_id"), [])
    unsupported = []
    for gpu in gpus:
        extra = profiles["gpu"][gpu["vendor"]]
        if extra is None:
            unsupported.append(gpu["vendor"])
        else:
            packages += extra
    return {"schema": 1, "architecture": platform.machine(),
            "cpu_vendor": cpu.get("vendor_id", "unknown"),
            "gpus": gpus, "laptop": bool(batteries), "batteries": batteries,
            "packages": sorted(set(packages)),
            "installer_supported": not unsupported,
            "unsupported_gpus": sorted(set(unsupported))}
