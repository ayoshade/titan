# Machine inventory — 2026-10-03

- Host/user: umbra / shade; Arch x86_64, kernel 7.2.8-arch1-2.
- HP laptop, Intel i3-1315U (six cores / eight threads).
- Intel Raptor Lake UHD graphics, existing i915 kernel driver and Mesa.
- BOE eDP-1 display: 1366×768, 60 Hz, 340×190 mm; scale 1.
- RAM: 7.4 GiB usable; existing 3.7 GiB zram swap.
- Samsung 238.5 GiB NVMe; existing 1 GiB EFI partition and Btrfs root/home.
- Realtek RTL8852BE-VT Wi-Fi, existing rtw89_8852bte driver.
- Network connection during installation: USB Ethernet; Wi-Fi disconnected.
- Audio: Intel SOF; sof-firmware already installed.
- Backlight: intel_backlight; battery: BAT0; AC adapter: ADP1.
- Existing active system services: NetworkManager, bluetooth,
  power-profiles-daemon, ufw.

No disk, filesystem layout, bootloader, firewall policy or kernel driver changes
were made by the configuration scripts. No NVIDIA configuration is required.
All direct desktop packages were available from official Arch repositories.
Installed versions can be recorded with `scripts/install-packages`; that
machine-specific record is ignored by Git.
