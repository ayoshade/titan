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
2. Suspend/resume verification is deferred: the user now requires always-awake
   operation and all sleep targets are masked. Only test it after an explicitly
   requested change to that policy.
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
  pairs share a chord. At this earlier stage physical codes were replaced with US keysyms based on
  an incorrect interpretation of empty exported key/keycode fields. The complete
  binding audit below corrects that finding: codes are supported internally.
- No user windows were closed, moved, grouped or resized during verification.
  Actual keypress behavior is a hands-on check; loaded bindings alone do not
  prove every compositor action under all window/layout states.

## Always-awake policy — live verification

- User ran scripts/install-always-awake with local sudo authentication. Original
  system destination files/target states are backed up under
  /var/lib/titan/always-awake/backup.sPyeT4. Initial profile was Performance with
  BatteryAware enabled; future installer runs also record those property values.
- Verified all five sleep targets masked and Performance service active/enabled.
- Live logind D-Bus properties report ignore for lid (all modes), sleep keys,
  power button and idle action. Reload completed without a session restart.
- ActiveProfile is performance, BatteryAware is false. System templates match
  installed files and the service completed successfully in the journal.
- Hypridle is stopped and absent from session-start. Stored idle config has no
  listeners. Monitor reports dpmsStatus true. Consoleblank was already 0.
- Automatic locking was removed with the idle timers; manual locking remains.
  Suspend tile is replaced by an always-awake indicator. Core checks and changed
  QML syntax passed; no actual sleep/lid test was forced on the running session.
- Configuration is persistent, but reboot behavior has not been exercised for
  this policy. Power loss and firmware/thermal protections remain physical limits.

## Complete Omarchy binding audit — 2026-10-03

- Pinned reference a85e29abb556816f4644cf975e98da694b486aa8; inspected all
  six binding files and relevant helper behavior. Executed reference and Titan
  registration in isolated mocked Lua environments and compared normalized
  modifier/key/release multisets: 231 expected, 231 actual, no missing or extra
  chords. Optional preinstalled application keys enabled; voxtype absent in both.
- Read the installed Hyprland commit's Lua parser: physical codes are stored in
  sMkKeys, while its exported key/keycode fields can be empty. Restored the exact
  physical codes from Omarchy. This corrects the earlier inventory interpretation.
- User installed the official workflow package set. Package checks pass; the
  event-driven titan-clipboard user service is active. Its initial unsupported
  size flag was corrected to an explicit bounded read and supported cliphist
  flags. No existing clipboard content was exposed in diagnostic output.
- Live picker test added eight scoped bindings, returned 0,0 1366x768 for full
  monitor selection, and removed all eight bindings on close. No screenshot of
  the user's working applications was saved as a project artifact.
- Created an isolated special-workspace test window. Tiled fullscreen on/off,
  floating/pinning on/off, width save/restore and transparency ran successfully
  against that address. Only the test window was closed; user windows were not
  closed or altered by these helper tests.
- Bounded calculator accepted arithmetic and rejected code execution, indexing
  and excessive powers. An isolated clipboard database retained exactly 100
  after 102 stores and excluded a marked-sensitive test item. Real clipboard
  contents and the user's database were not read for those tests.
- Eighteen new Quickshell menus opened and closed with no new runtime warnings.
  Root menu visually inspected at the laptop resolution. User-selected palette
  and unrelated generated theme changes were preserved.
- Top-bar visibility was changed through typed IPC, persisted to private state
  and restored to its original value.
- Doctor, compositor validation and live configerrors passed. Always-awake
  targets remain masked, Performance is active, BatteryAware is false and no
  hypridle process runs. No lock, sleep, logout, shutdown or close-all test ran.
- Exact chord parity is not a claim of every Omarchy feature/application being
  present: optional apps, shared panel equivalents, always-awake exceptions,
  live rather than frozen selection, and transient reminders are documented.
  Physical keyboard, external monitors, webcam, actual recording/OCR, media
  output switching and reliable Hyprlock rendering remain hands-on checks.

## Notch geometry match — 2026-10-03

- Measured saneAspect's compact island from native 1080p frames (J8s7O2IGogE,
  10:30–10:55) and rebuilt `modules/Bar.qml` to match it.
- The live shell was restarted with `scripts/shell-restart`, and no QML runtime
  warnings were logged. A grim capture measured the pill at 230×33, top y=11,
  centred on eDP-1. The volume OSD expansion and clock panel were opened through
  IPC and displayed correctly. `scripts/doctor` passed.
- Not hands-on tested: pointer clicks on workspace marks, the clock and status,
  the low-battery colour, and a Wi-Fi signal (this machine was on Ethernet).

## Island dashboard — 2026-10-03

- Built the click-expanded dashboard from frames of J8s7O2IGogE (10:36–10:55,
  including 30 fps transition scans). Reference and Titan were compared side by
  side at 1:1 scale.
- Live checks: the shell reloaded with no runtime warnings after fixes. The
  dashboard opened and closed through `ipc call shell island`. Rapid grim captures
  confirmed the open overshoot (peak ~650×167, settling at 648×167) and the
  height-then-width close. `scripts/workflow game-mode` was toggled on and off: all
  three Hyprland options went false, then were restored to true, and the runtime
  state file was removed. `scripts/workflow toggles` reported both states.
  `scripts/doctor` passed.
- An invalid fractional `font.pixelSize` briefly stopped the shell from loading
  during development. Run a live reload after QML edits, because qmllint did not
  catch it.
- Not hands-on tested: the media row with a live MPRIS player (none was playing),
  pointer hover/leave collapse, Escape, the Night light chip (it would start
  wlsunset), clicking workspace rows, and a dashboard on a second monitor.
