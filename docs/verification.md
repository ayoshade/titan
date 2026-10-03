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

## Graphical login setup

- Installed greetd 0.10.3-2, greetd-regreet 0.5.0-1 and Cage 0.3.1-1.
- TOML parsed successfully; installed ReGreet and Cage CLI options checked.
- greetd systemd unit validates; display-manager.service points to greetd.
- greetd enabled, graphical.target default confirmed. The service was not
  started over the current TTY/desktop.
- Installed config and greeter stylesheet match the reviewed repository files.
- greeter account and ReGreet state/log directories exist with correct ownership.
- ReGreet demo launched and loaded the dark configuration; native login user
  shade and installed Wayland sessions were detected. Demo exited afterward.
- Preview reported a system locale C warning, benign GTK empty-declaration
  warnings, and missing remembered state before the first real login.
- Real reboot/login verified on 2026-10-03: greetd opened a session for shade,
  Hyprland started, and Quickshell/Hypridle launched automatically. Core system
  services and the repeatable doctor checks passed after reboot. No automatic
  login is configured.

## Dynamic-island redesign — 2026-10-03

- Studied English auto-captions from saneAspect's October 2 workspace-island
  video and October 1 design discussion; inspected sampled frames of the
  latest video and the full September 19 visual walkthrough. Source links and
  adaptations are recorded in design-reference.md.
- Rebuilt the bar as a centered island with native reactive workspace marks,
  compact clock/status icons, two side buttons and expanding hardware OSDs.
- Visually inspected controls, launcher, connections, calendar, appearance,
  session, media, notifications and toast at 1366×768. The test workspace was
  closed and the original workspace restored after captures.
- Runtime opened every panel without warnings in the final clean shell run.
  Launcher icons have a local vector fallback for unavailable theme icons.
- Accent preference written through native FileView, persisted across shell
  restart, then restored to silver. Original landscape rendered successfully.
- Volume OSD rendered without changing volume; native notification appeared
  both as a centered toast and in the history panel.
- All QML passed syntax parsing. Static qmllint still has upstream type-analysis
  warnings; this is not a claim of a warning-free static type check.
- Doctor, compositor validation, live configerrors and git diff checks passed.
- No additional packages, system login edits, boot edits, destructive operations,
  radio changes, suspend or power actions were needed for the redesign.
- Actual playback/artwork, tray menu interactions and external-monitor behavior
  remain hands-on checks. Existing authentication/suspend limitations above
  remain; this visual redesign does not resolve them.
- Final shell RSS observed at 203728 KiB (about 199 MiB), with 0.6% CPU over
  one five-second idle sample after panels closed. This is a brief observation,
  not a sustained performance benchmark.

## Theme switcher

- Inspected the reference video’s theme-picker frame at 05:50 and rebuilt the
  horizontal search/palette-card layout in Quickshell.
- Nine palette catalogs validated for unique IDs, valid RGB tokens and six
  swatches each. Unknown IDs reject without changing generated files.
- Live picker loaded without runtime warnings and fits the 1366×768 screen.
- Applied Nord through the native IPC/Process path; shell state and generated
  Kitty palette matched. Live compositor configuration errors remained empty.
- Saved palette survived shell restart; Graphite was restored after testing.
- Super+T binding verified in the live compositor. Doctor and QML syntax
  parsing passed. Pointer/keyboard navigation still benefits from user feedback.
- Theme application affects Quickshell, Kitty and Hyprland borders. It does not
  swap GTK themes, browser styling or wallpapers.
- Shell restart now waits for the old instance to release its single-instance
  lock, preventing the replacement from exiting during a restart race.

## Omarchy-inspired shortcuts

- Inspected current Omarchy application, tiling and utility bindings from its
  public quattro branch; sources and Titan mappings are in docs/keybindings.md.
- Added focused-window close, window/workspace cycling, scratchpad, grouping,
  swaps, resizing and installed-application aliases using native Hyprland Lua.
- Moved theme selection to Super+Ctrl+Shift+Space; Super+T now toggles floating.
- Static compositor validation, live reload/configerrors and doctor passed.
- Live binding inventory resolves all keys. Only intentional Alt+Tab focus/raise
  pairs share a chord. Physical code bindings were replaced with US-keyboard
  keysyms because the installed build exposed unresolved keycodes in its inventory.
- No user windows were closed, moved, grouped or resized during verification.
  Actual keypress behavior is a hands-on check; loaded bindings alone do not
  prove every compositor action under all window/layout states.
