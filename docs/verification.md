# Verification

## Completed during setup

- All manifest packages installed from Arch repositories, including Hyprland
  0.56.2-3 and Quickshell 0.3.1-1.
- `Hyprland --verify-config`: config ok; live `hyprctl configerrors`: empty.
- Bash syntax checked for all scripts; bootstrap run twice successfully.
- Live Quickshell loaded without runtime warnings after corrections.
- IPC exercised for launcher, controls, notifications, session, close and
  brightness OSD. No suspend, shutdown or reboot action was executed.
- Desktop, control center, launcher and notification history visually inspected
  at the physical 1366×768 resolution.
- Network list populated through native API without disconnecting Ethernet.
- Native notification delivered and rendered in retained history.
- PipeWire sink volume, battery, brightness, and power profile populated.
- Kitty and Thunar launched; Hyprland reports `xwayland: false` for both.
- Hyprland explicit DPMS-on Lua dispatcher returned ok and remained on across
  repeated calls. Idle commands use table arguments with an explicit action.
- Initial Hyprlock rendering stalled during TTY switching. Immediate rendering
  and disabled locker animations were applied. The replacement subsequently
  logged successful PAM authentication, unlocked and exited. The user regained
  the desktop. Reliable visible lock rendering during TTY switching remains
  unresolved; successful authentication does not establish that it is fixed.
  No password was collected by the agent.
- GTK, Hyprland and core XDG portals active.
- NetworkManager, Bluetooth, power profiles and UFW remain active.
- Quickshell resident memory observed around 202 MiB after opening all panels;
  process lifetime CPU around 0.9% during interactive checks. These are a brief
  observation, not a steady-state benchmark.

## Hands-on checks still required

1. Retest visible lock rendering from the desktop without switching TTYs.
   Authentication succeeded in recovery, but black-screen rendering was observed.
2. Suspend from the session menu: resume requires authentication; display,
   audio, Bluetooth and network recover.
3. Test actual speaker/microphone output, audio-device switching, brightness
   keys and media playback with an MPRIS-capable application.
4. Join a known Wi-Fi network and pair a Bluetooth device. Ethernet remained
   connected during setup; credentials and radio state were not changed.
5. Print: select a region, verify the saved PNG and clipboard paste.
6. Firefox: test file dialogs and an explicit screen-sharing request. Portal
   activation was checked; no external call was initiated.
7. Plug in an external monitor if used; verify scaling, bar and focused-screen
   overlays. Only the internal screen was available during setup.

Run `~/dotfiles/scripts/doctor` for repeatable static/package/service checks.
The script does not claim to validate real authentication, suspend, hardware
output, screen-share negotiation or device pairing.

## Kernel observation

At 03:36:59 on 2026-10-03 the kernel logged a missing SystemCMOS address-space
handler for region CMS0 and aborted ACPI method `_SB.PC00.LPCB.EC0._Q33` with
AE_NOT_EXIST. This was after the initial black-screen report. The observation
does not establish a causal connection to Hyprlock. The rtc_cmos driver exists
and RTC devices rtc0/rtc1 are present. No ACPI overrides, firmware changes,
kernel parameters or bootloader edits were applied.
