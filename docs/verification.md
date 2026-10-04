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

1. Lock after a TTY switch on the laptop: fixed by `scripts/vt-redraw` and
   confirmed by the owner on 2026-10-03 (see below). The QEMU test now covers rendering, crash restore
   and faillock lockouts; see "Lock screen diagnosis" below and
   `docs/lock-recovery.md`.
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

## Island calendar morph — 2026-10-03

- Measured the reference calendar state from 30 fps frames (J8s7O2IGogE
  10:37.4–10:39.3). It is 336×280, and pointer leave collapses it to compact.
- Live checks: the calendar was opened through IPC from the dashboard. Rapid
  grim captures showed 648×167 → 334 (undershoot) → 336×280. Closing narrowed
  first, then dropped height to 230×33. The calendar matched the reference
  side by side at 1:1.
- Found and fixed: the fixed-height layer surface clipped the calendar at 199 px
  until it was sized to the tallest state.
- Not hands-on tested: pointer clicks on the month buttons, wheel paging,
  Left/Right keys and Super+Ctrl+Alt+D.

## Control center, Settings, wallpapers and dashboard fix — 2026-10-03

- **Dashboard clicks (user report):** workspace rows in the dashboard did not
  respond. Debug logging showed that exclusive keyboard focus made Hyprland
  send the island a pointer leave as it opened; the leave timer then collapsed
  it. On-demand focus keeps hover. Scripted pointer warps only produce
  enter/leave events, so this was verified through hover and enter logging,
  not real clicks.
- **Control center:** opened through IPC; the main page and Wi-Fi drill-in
  rendered with no warnings. Bluetooth, Sound and Display pages were not
  opened in this session.
- **Settings window:** floats at 820×560 through `config/hypr/rules.lua`, and
  `hyprctl configerrors` is clean. Bar & Island, Appearance, Motion and System
  were captured. A `scripts/workflow settings set islandWidth 300` change
  resized the live island, `reset` restored it, and an out-of-range value
  exited 1. Notch mode was toggled on, inspected and reset.
- **Wallpapers:** applying nord switched the wallpaper to the nord set, the
  theme and wallpaper carousels rendered, and `wallpaper next` crossfaded.
  Industrial was then restored, with Blacksite pinned as its wallpaper. The
  first fetch mapped pastel accents to greys, so those sets were replaced
  after the colour match became hue-aware.
- **A broken hot reload:** a missing `;` briefly broke the hot-reloaded
  configuration. The previous generation kept running behind an error banner
  until the fix.
- **Not hands-on tested:** real clicks on dashboard rows, control-center tiles
  and Settings controls; Bluetooth connect; per-app volume; the
  wallpaper-carousel keyboard; font changes across all panels.

## Menus, session, notifications and media — 2026-10-03

- **Menus:** the launcher, the Titan root menu, the toggle submenu and
  keybindings were opened through IPC and visually compared with the
  reference launcher frames. A
  `count` id collision first left the lists empty; it was fixed and verified.
- **Session menu:** rendered with tiles. The control-center power strip was
  checked with lint only, because opening it needs a click.
- **Notifications:** three test notifications showed the toast below the
  island, and the notification center grouped them by app with "+1 more".
  They were dismissed afterwards. The media panel rendered the blurred
  album-art card.
- **Game-mode bar:** `workflow game-mode` showed the full-width bar; toggling
  again restored the island, and the Hyprland effects read back as enabled.
- **Night light:** at 3500 K, `wlsunset -t 3500` ran, then it was turned off
  and the setting reset.
- **Shell freezes (twice):** `qs kill` sometimes leaves Quickshell deadlocked
  while exiting, holding the instance lock, so the desktop had no responsive
  shell. Recovery was SIGKILL and a relaunch. `scripts/shell-restart` now
  escalates and passed three consecutive restarts.
- **Doctor:** it had failed since `fetch-wallpapers` was added, because it
  ran `bash -n` on a Python file. It now parses scripts by shebang and exits 0.
- **Not hands-on tested:** clicks in the power strip and session confirmations
  (deliberately not confirmed), launching apps from the new launcher, menu
  submissions (calculator, reminder), emoji copy, and notification actions.

## Quickshell exit crash, root cause — 2026-10-03

- A symbolized core (`coredumpctl debug 23078`, using Arch's debuginfod)
  shows `qFatal("QPixmap: Must construct a QGuiApplication before a
  QPixmap")`. It is raised from `QWindow::unsetCursor()` while
  `QQuickItem` destructors run after the application object was destroyed.
  This is an upstream Quickshell 0.3.1 teardown bug, not Titan QML. It explains
  the SIGABRT and SIGSEGV cores and the occasional hang on `qs kill`; the
  workaround is the escalating `scripts/shell-restart`. The procedure is
  recorded in `default/agents/skills/diagnose-crash/SKILL.md`.

## Phase 1: user layer, version, migrations — 2026-10-03

- **Live migration:** before running, the old state, the tracked preferences,
  generated files and `mimeapps.list` were backed up to the session scratch
  directory. `titan migrate` then applied `1791060086-user-layer.sh` on this
  machine:
  - the industrial preferences moved to `~/.config/titan/preferences.json`;
  - settings moved to `~/.config/titan/settings.json`;
  - `~/.config/mimeapps.list` became a real file and kept the Claude Code
    handler;
  - the generated Kitty theme was byte-identical to the old tracked file;
  - `hyprctl configerrors` was empty.
- **Repeat runs:** a second `titan migrate` reported nothing pending.
- **Throwaway homes:** in an old-layout home, settings moved, the user layer
  was created and the theme was generated, and a re-run was a no-op. On a
  fresh home, `--mark-all` recorded the migration without running it.
- **Round-trip:** after a clean `titan-shell restart` (no shell warnings),
  `titan theme nord` changed the shell, the user preferences, the generated
  Kitty file and the Hyprland border (88c0d0). `titan theme industrial`
  restored them. `git status` showed no user changes: switching themes no
  longer dirties the checkout.
- **titan-app template:** rebuilt and run; it followed industrial → horizon
  live through the new paths.
- **Sound page fix:** its PipeWire tracker referenced `parent` from a
  non-Item, so per-app volume tracking got `undefined`. It now uses an id.
- **Not exercised:** `titan update`, because it needs sudo and the network.
  The user should run it the first time.
- **Snapshots:** `scripts/install-snapshots --dry-run` on this machine detected
  btrfs `subvol=/@`, no existing Snapper config, and missing
  `snapper`/`snap-pac`, and listed the five intended actions. The real run
  (sudo) is pending the user. Neither `undochange` nor the full rollback in
  `docs/snapshots.md` has been rehearsed; do that in a VM.
- **`TITAN_ROOT`:** after the change, `hyprctl configerrors` was empty and the
  restarted shell process carried `TITAN_ROOT=/home/shade/dotfiles`
  (inherited from Hyprland's `hl.env`). `titan-shell ipc theme industrial` ran
  `apply-theme` through `Paths.script()`. The root menu opened, and the shell
  log was free of Titan warnings. Not exercised: key-triggered lock and
  session-start, which run at the next login.
- **First real update and snapshot setup (run by the user, checked
  read-only):**
  - `titan update` upgraded hyprland 0.56.2-3→-4 and libutf8proc; the kernel
    was unchanged, so no reboot was needed.
  - `scripts/install-snapshots` installed snapper 0.13.2 and snap-pac 3.0.1,
    created the `root` config and took snapshot 1 ("titan: snapshots enabled").
  - Config check: TIMELINE_CREATE=no, NUMBER_LIMIT=10/5, ALLOW_USERS=shade,
    and `snapper-cleanup.timer` is active. `snapper-timeline.timer` is enabled
    but creates nothing while the timeline is off.
  - snap-pac's pre/post pair appears at the next pacman transaction.

## Phase 1: packaging and first run — 2026-10-03

- **Hyprland:** with `base` taken from `TITAN_ROOT`, `Hyprland --verify-config`
  printed `config ok` and live reloads had no errors.
- **Existing install:** `titan migrate` applied `1791060868-first-run-markers`
  here (setup-version and welcome-done recorded).
- **Welcome screen:** it did not open after a restart, because the marker
  exists. It rendered when opened through IPC. With the marker moved aside it
  opened by itself at startup (panel `welcome`); the marker was restored
  afterwards.
- **Packages:** `makepkg` built `titan` (208 entries: no `__pycache__`, `.git`
  or user files) and `titan-desktop` (40 dependencies).
- **Packaged tree:** extracted into a throwaway root, with a fresh home:
  - `titan setup` created the user layer, the thin Kitty config, the GTK and
    mimeapps defaults and the graphite theme;
  - both migrations were recorded as done;
  - `Hyprland --verify-config` on the packaged config printed `config ok`;
  - the packaged shell QML linted cleanly.
  The test's `gsettings` and `systemctl --user` calls hit this real session
  but set values it already had.
- **Repository:** `build-repo --channel edge` produced a valid repository
  database. A stable build correctly refused uncommitted changes.
- **`vm-test --full`: passed all 14 checks** on Arch's official cloud image
  (QEMU/KVM, 2 GB, kernel 7.2.7) after `qemu-base` was installed.
  - A full `pacman -Syu`, then `titan` and `titan-desktop` with all 40
    dependencies installed.
  - `titan setup` worked on the first run and on a repeat.
  - The default theme is graphite, and no migrations were pending.
  - The user layer, thin Kitty config, `/etc/xdg` shell and Titan session
    file were all present.
  - Hyprland accepted the packaged config, and the shell QML parsed.
  - Settings and theme round-trips worked.

  Two earlier attempts failed because this laptop's OOM killer ended QEMU:
  the VM had 4 GB on a 7.5 GB host, and its overlay disk was in the
  RAM-backed `/tmp`. `vm-test` now keeps runs under `~/.cache/titan/vm/runs`,
  defaults to 2 GB (`--memory`), refuses to start without enough free memory,
  and stops at once if QEMU dies. Package installs run as a detached
  `systemd-run` job polled over short SSH calls. A graphical login to the
  Titan session is still untested (Phase 2).

## First public release — 2026-10-03

- **Published:** `scripts/publish-repo --channel stable --sign 8A648F6B462B95C6
  --yes` published Titan 0.2.0 as the `repo-stable` release, with 12 assets:
  both packages, the database and files lists, and a `.sig` for each. The
  owner entered the passphrase in GPG's own prompt.
- **Visibility:** `ayoshade/titan` was private, so release assets returned
  404 to anonymous clients. With the owner's approval the repository was made
  public (a history scan found no secrets; the commit email and laptop notes
  are visible). The first anonymous requests still returned 404 for a short
  time while GitHub propagated the change.
- **Anonymous check:** an unauthenticated download of `titan.db`, both
  packages and their signatures, verified against
  `raw.githubusercontent.com/.../keys/titan-packager.asc`, gave "Good
  signature" for all three. The database lists `titan-0.2.0-1` and
  `titan-desktop-0.2.0-1`.
- **Install from the public repository: passed.**
  `scripts/vm-test --full --from-repo` followed the documented user steps on a
  clean Arch cloud VM:
  - the public key came from raw.githubusercontent.com and was added and
    locally signed;
  - `[titan]` was appended to `pacman.conf`;
  - `pacman -Syu titan-desktop` ran with default signature enforcement;
  - pacman reported `Validated By: SHA-256 Sum  Signature`.

  All 14 checks passed.

## Documentation audit and package release 2 — 2026-10-03

- **Documentation audit:** every repository path in the README, AGENTS.md,
  docs and skills was checked against the tree (only intentional examples
  remain). Every `titan-shell ipc`/`ipc call shell` function exists in
  `shell.qml`, every `scripts/workflow` operation in the dispatcher, every
  setting in the schema, and the live bind count is 231. The README was
  rewritten from the current code.
- **Packaging gap:** the published `titan 0.2.0-1` lacked `packages/`,
  `system/` and `keys/`. So `titan doctor`, `install-login` and
  `install-always-awake` could not work on packaged installs. `doctor` also
  wrote bytecode and required developer links. Release 2 ships those
  directories, and `doctor` is mode-aware: static checks are fatal, and on
  packaged installs missing packages, setup and optional services are
  warnings. On this laptop it behaves as before.
- **VM test:** `vm-test --full` on the local 0.2.0-2 build passed 16/16,
  including `titan doctor (package mode)` and the shipped login inputs.
- **Release 2 published:** `titan 0.2.0-2` was signed and published, and the
  stale `-1` package was pruned. `titan-desktop` stays `0.2.0-1` because its
  contents did not change.
- **Install from the published repository:** `vm-test --full --from-repo`
  passed 16/16, with `Validated By: SHA-256 Sum  Signature`.

## Phase 2: experimental ISO and dedicated-disk installation — 2026-10-03

- **Development version:** 0.3.0-1, not published or signed. Stable remains
  0.2.0-2. The new installer checks repository version before erase and refuses
  the older stable channel; these installation tests used an explicit unsigned
  repository available only to the disposable QEMU guest.
- **Complete install and independent boot: passed.**
  `scripts/vm-install-test` booted the newly built UEFI ISO using OVMF and a
  blank 40 GiB qcow2 disk. The real installer:
  - accepted the exact erase confirmation and terminal password prompts;
  - created GPT, 1 GiB FAT32 EFI and Btrfs `@`, `@home`, `@log`, `@pkg`;
  - installed Arch base, hardware packages, `titan` and `titan-desktop` 0.3.0-1;
  - generated locale/fstab, created a wheel account, locked root password
    login, enabled login/network/Bluetooth/power services and installed
    systemd-boot and the Titan Plymouth hook/theme;
  - unmounted its target without requesting a reboot.

  The harness added test-only SSH access, stopped that VM, **detached the ISO**
  and booted its installed disk. Btrfs root and active greetd were checked over
  SSH. ReGreet authenticated a new account into `titan-session`; Hyprland had
  no config errors; Quickshell IPC returned `panel=welcome`, `theme=graphite`,
  `screen=Virtual-1`. Setup-version exists and welcome-done does not.
- **Visual review:** QEMU screenshots at 1280×800 showed the centered Titan
  wordmark/progress dots, dark ReGreet login, wallpaper and first-login Welcome.
  Eighty boot frames were captured and inspected as contact sheets, with the
  splash, greeter and Welcome also viewed at full size. There is a brief
  libseat seatd-probe message before Cage falls back successfully to logind.
  This boot handoff still needs polish; it was not hidden or mistaken for a
  failed login. No host application screenshots were taken or committed.
- **Runtime limits:** the installed shell log has a BlueZ object-manager
  warning (the VM has no Bluetooth adapter) and a Qt portal app-registration
  warning. Configuration loaded and IPC responded. The earlier cloud-image
  test also warned about missing network/UPower/power-profile services; the
  complete desktop now declares those packages in `packages/services.txt`.
  The installed-disk shell no longer reports those missing backends.
- **Package regression:** the final `vm-test --full --reuse …` passed **17/17**
  on 0.3.0-1, including the explicit requested-version check, setup repeat,
  theme/settings preservation and round-trips, packaged Hyprland/QML and doctor.
  Reuse previously selected old archives already in the guest's home: it now
  installs exact current-version filenames from a dedicated test directory.
- **First-login regression:** `titan-session` creates the state directory and
  setup.log before setup. Treating that directory as an existing installation
  ran the legacy welcome-marker migration on a fresh user. Setup now ignores a
  lone setup.log when deciding freshness. A real fresh login shows Welcome;
  a throwaway-home regression verifies fresh markers, repeat behavior and
  preservation of an existing Hyprland override without touching host services
  or applying a theme.
- **Safety/unit checks:** 11 tests cover whole-disk boundaries, nested mounts,
  swap, storage holders, read-only/small/loop targets, non-live/non-QEMU apply
  rejection, development repository bounds, account/timezone validation,
  first-login detection and Intel/AMD/virtual/NVIDIA/unknown hardware selection.
  Host `scripts/doctor`, live `hyprctl configerrors`, script/Python syntax and
  `git diff --check` passed. The internal mounted NVMe was rejected by the
  read-only planner; no host partition or boot changes were made.
- **ISO build:** Archiso 91-1, built as root inside the isolated QEMU build
  guest, UEFI systemd-boot profile, zstd SquashFS. The ISO is ≈1.6 GiB and its
  SHA-256 check passes. An early launch failed because Archiso normalizes file
  permissions; the executable is now explicitly declared in file_permissions.
  A separate launch was interrupted by editing the running Bash harness;
  the successful run used a syntax-checked file. No disk writes happened in
  either of those failed launches.

  Local test image: `~/.cache/titan/vm/runs/run.mkTYG7/iso/`.
  Passing installed-disk artifacts: `~/.cache/titan/vm/runs/install.QsLfLe/`
  (install plan/log, hardware, shell status/logs, UI screenshots and boot
  frames). The final ISO already contained the overlaid installer module;
  the harness used the same source. Test images contain an ephemeral SSH
  public key and must not be distributed. All QEMU processes were stopped
  after verification.
- **Still open:** encryption, dual boot/manual partitioning, wider VM and
  multi-monitor coverage, real GPU/laptop tests (especially NVIDIA), smoother
  splash-to-greeter handoff, signed 0.3.0 channel testing, ISO source/license
  review and a public image without test access. Suspend/lock rendering on the
  development laptop remains untested under its always-awake policy.

## Omarchy developer skills port — 2026-10-03

The initial location and registration described below were corrected in the
following handoff section. The current inventory is `docs/agent-skills.md`.

- Reviewed all seven guides in Omarchy's `agents/skills/` at quattro revision
  `8e02fc84f5bdc511ed102e2a14f8935bba4f92bd`, plus its existing end-user skill
  inventory. Added `titan-commands`, `titan-installation`, `titan-shell-dev`,
  `titan-icons`, `titan-acceptance-tests`, `titan-visual-verification` and
  `titan-migrations`. The three existing Titan end-user skills are preserved.
  Commands, paths, SVG assets, shell lifecycle, setup, migration semantics and
  QEMU test interfaces follow Titan's implementation rather than nonexistent
  Omarchy compatibility APIs. Source mappings are in `docs/agent-skills.md`.
- Retained the full upstream MIT license in `default/agents/LICENSE.omarchy`,
  declared the adaptation in `NOTICE`, and installed its license text under
  `/usr/share/licenses/titan/`. No Omarchy executable, font, plugin registry or
  dotfiles were installed.
- Added `titan skills [--dry-run]` with complete destination preflight,
  CODEX_HOME support, idempotent links and refusal of custom entries/broken
  foreign links. Setup/update register new bundled skills, warning on conflicts
  without replacing personal skills or preventing desktop setup.
- **Local registration passed:** ten bundled directories resolve correctly in
  both Codex and Claude; the seven new skills are linked to the checkout. A
  subsequent preview is silent. All ten skill frontmatters pass the
  skill-creator validator; local Markdown references resolve. Validator PyYAML
  lives only in a disposable cache venv, not Titan's runtime dependencies.
- **Automated checks passed:** 17 unittest checks (six new registration tests
  plus the existing eleven), including preview without writes, path relocation
  with spaces, custom CODEX_HOME, repeat without replacing links, preservation
  of personal skills/broken links, atomic conflict refusal, blocked parent
  directories and invalid arguments. The first-login fixture also exercises
  setup's registration in an isolated HOME/CODEX_HOME.
- **Package VM checks passed: 18/18.** The rebuilt 0.3.0-1 development package
  installed after a successful full upgrade in the reused disposable QEMU
  guest, and setup linked every bundled skill for both agents. Both license
  locations were verified. Artifacts/log:
  `~/.cache/titan/vm/runs/run.mkTYG7/install.log`.
- Two earlier package checks failed on missing new links: the guest had a
  stale pacman database lock, so the package transaction never ran. The harness
  incorrectly accepted a previous install success marker. It now clears that
  marker before each job, requires systemd's successful Result as well as the
  new marker, and preserves the installation log. The unused lock was removed
  only inside the disposable guest after checking for active pacman/lock users;
  the complete package run then passed. No host package transaction ran.
- Host `scripts/doctor`, Bash syntax and `git diff --check` pass. The live shell
  still responds with the user's industrial theme on eDP-1. No QML/compositor,
  boot, power or shortcut settings changed; no visual or lock/suspend test was
  needed for the guide/registration work. The test VM was stopped on exit.
- New sessions can discover the linked skills. There is no persistent bundled
  skill opt-out yet: removing a discovery link is reversible, but setup/update
  registers it again. Static guide validation and package integration checks
  do not claim forward-testing every development recipe or a new public release.

## Development and end-user skill locations corrected — 2026-10-03

- The user clarified the two locations: all seven development guides now live
  in `agents/skills/`; `default/agents/skills/` contains exactly `titan`,
  `titan-app` and `diagnose-crash`. The guides were moved intact, with the MIT
  notice at `agents/LICENSE.omarchy`. AGENTS task links, documentation, NOTICE
  and the package's license source path now match this layout.
- Development guides are read through repository `AGENTS.md`. Setup/update
  and `titan skills` scan only end-user defaults. Packaging excludes the
  repository's `agents/` tree while retaining the upstream license in
  `/usr/share/licenses/titan/`.
- Removed only the fourteen mistaken development-guide symlinks created by
  the preceding task in the owner's Codex/Claude skill directories, checking
  their exact targets first. The three end-user links in both homes and all
  unrelated skills were preserved. No desktop configuration or service changed.
- Validation passed: all ten skill definitions and their relative references,
  AGENTS links, Bash syntax, `git diff --check`, host doctor, and 18 unittest
  checks. Registration tests include a checkout with both trees and prove only
  the three defaults are registered while a personal development skill remains
  untouched.
- The rebuilt package archive contains only the three end-user SKILL.md files
  and the license. `scripts/vm-test --full --reuse …` passed 18/18 in QEMU,
  explicitly asserting three packaged/registered end-user skills and no
  `/usr/share/titan/agents` tree. Artifacts remain in
  `~/.cache/titan/vm/runs/run.mkTYG7/`; QEMU stopped on exit. No ISO, graphical
  layout, lock or suspend retest was needed for this location correction.

## Installer interruption recovery — 2026-10-03

- Added an atomic, private live-session journal under `/run/titan-installer/`
  with installer checkpoints, disk identity, intended mounts, filesystem UUIDs
  and subvolume roots. It excludes passwords, subprocess input/output and
  command arguments. `titan-install --status [--json]` reads the journal and
  current mounts without creating state. `--recover --disk DEVICE` requires
  the live root/UEFI/QEMU guards and an exact `RECOVER DEVICE` confirmation.
- Recovery rechecks identity and mount ownership after confirmation, refuses
  outside mounts/swap, holders, changed filesystems, unrecorded/foreign mounts
  and busy filesystems, and uses ordinary recursive unmount (never lazy/force).
  It removes only the empty retry directory and preserves partial disk data.
  A fresh install still requires another ERASE and new password entry. This is
  cleanup and restart recovery; resume across live boots is not implemented.
- Installer commands inherit an exclusive operation lock. A surviving worker
  retains it when its installer is killed. Ordinary failures record the failed
  step and attempt safe unmount without hiding the original command error;
  interrupts leave the mounts for explicit recovery. Completed installs record
  `installed`/`complete` after cleanup and leave no target directory or mounts.
- **Local checks passed: 33 unittest checks**, including identity/UUID/boot
  changes, wrong Btrfs subvolume, mounts appearing during confirmation, outside
  mounts/swap, busy cleanup, cancellation, wrong disk, corrupt journals,
  nonempty-directory preservation, inherited child locks, journal write failure,
  CLI read-only JSON enforcement and non-live recovery refusal. Host doctor,
  Python/Bash syntax and `git diff --check` passed. The package baseline VM
  regression also passed 18/18.
- **Live failure and recovery checks passed** with
  `scripts/vm-install-test RUN --recovery` on a new 40 GiB QEMU disk:
  - an injected pacstrap exit 72 recorded `failed`/`base-packages`, preserved
    that error and released all target mounts;
  - a SIGKILL left the checkpoint and five filesystem mounts; recovery refused
    while the surviving test worker retained the inherited lock;
  - a foreign tmpfs stacked on `/boot` was refused and remained mounted;
  - a process holding the target as its working directory caused a real busy
    unmount failure, retaining the retry marker;
  - cancelled and wrong-disk recovery changed nothing; confirmed recovery then
    removed the target mounts/empty directory while preserving both filesystem
    labels. A new separately confirmed installation proceeded successfully.
  Fault injection is confined to the test harness, not shipped installer flags.
- **Current ISO and independent boot passed.** A new ISO was built in QEMU and
  its SHA-256 verified. Before any development overlay, both embedded installer
  files matched the current checkout hashes (`iso-source-check.json`). The final
  install status was `installed`/`complete`, `busy=false`, no target directory
  and no mounts. The harness detached the ISO and booted the installed disk,
  authenticated through ReGreet and verified first-login setup/Welcome, the
  graphite shell on Virtual-1 and empty live compositor errors. Greeter and
  Welcome screenshots were visually inspected at 1280×800. The VM shell still
  reports the previously documented missing-BlueZ-adapter and Qt portal
  registration warnings; this change does not resolve them.
- **Build capacity:** the reused 24 GiB build guest filled during an initial
  ISO rebuild. Its log is retained as `build-iso-recovery-disk-full.log`. Only
  that verified VM was stopped; its qcow2 disk was expanded to 64 GiB, then its
  third partition and Btrfs filesystem were grown inside the guest. The rebuild
  passed. No host disk, partition, bootloader, package, power policy or desktop
  configuration changed. All task-owned QEMU processes stopped; the owner's
  industrial shell still responds and live `hyprctl configerrors` is empty.
- **Artifacts:** current test ISO/build logs under
  `~/.cache/titan/vm/runs/run.mkTYG7/`; passing recovery/install logs, source
  hashes, status JSON and graphical captures under
  `~/.cache/titan/vm/runs/install.VqHudD/`. The previous ISO is retained under
  `run.mkTYG7/iso/previous/recovery-baseline/`. Test images contain temporary SSH
  access and must not be distributed; nothing was signed or published.
- **Next work:** encryption, interrupted-install resume across boots, wider
  VM/hardware coverage, signed 0.3.0 upgrade/install validation and public-image
  source/license review remain open. The laptop's visible lock rendering and
  other hands-on hardware checks remain separate outstanding tasks.

## mise as the default tool manager — 2026-10-03

- Added `mise` to `packages/workflow.txt` (so `titan-desktop` depends on it),
  `default/bash/rc` (activates mise only when installed), and
  `scripts/install-bash-defaults` (appends one marked line to `~/.bashrc`),
  called by `titan setup` and migration `1791072383-bash-defaults-mise`.
  `hyprland.lua` prepends the mise shims directory to the session `PATH`, guarded
  against duplicates on config reload.
- Verified in throwaway homes: a missing `~/.bashrc` is created, an existing one
  is only appended to, a second run changes nothing, the migration applies the
  same hook, and a shell without mise still loads cleanly.
  `Hyprland --verify-config` passes and the Bash syntax checks pass.
- The owner installed mise 2026.10.0 and moved `gh` to it (`mise use -g gh`,
  2.102.0; the copied `~/.local/bin/gh` was removed). Interactive Bash resolves
  `gh` through mise, the shim works with the existing `gh` login, and
  `scripts/doctor` passes again.
- Not yet verified: shim PATH in a live session needs a Hyprland
  restart (or a new login) and a `mise use -g` tool launched from a keybinding.

## Layout split step 1: developer tools in `tools/` — 2026-10-03

Following `docs/layout-plan.md`, `build-iso`, `build-repo`, `publish-repo`,
`vm-build-iso`, `vm-graphical`, `vm-install-test` and `vm-test` moved from
`scripts/` to `tools/`. Each still resolves the root from its own location, so
only callers and docs changed. Historical entries above keep their old paths.

- Verified: Bash/Python syntax of all tools, `scripts/doctor` (now also parses
  `tools/*`), 33 unit tests, and `tools/build-repo --channel edge` builds both
  packages; the `titan` package contains no `tools/` or VM/build/publish scripts.
  `tools/vm-test` gained a check that developer tools are not packaged.
- Not yet verified: `tools/build-iso --prepare` (needs archiso, absent on this
  laptop) and the VM runs (`vm-test --full`, `vm-build-iso`, `vm-install-test`).
  These are part of step 5 of the plan.

## Layout split steps 2–4: public commands in `bin/` — 2026-10-03

`titan`, `titan-shell`, `titan-session`, `titan-install` and `workflow` moved to
`bin/`, with relative `scripts/NAME → ../bin/NAME` compatibility links. Callers
updated: Hyprland bindings, `Paths.qml` (`workflow`, new `bin()`), Quickshell
users of `Paths.workflow`, `lib/titan/workflow.py`, helper scripts, `bootstrap`,
the PKGBUILD (`/usr/bin` links, `bin` copied) and the ISO (`/usr/share/titan-installer/bin/`).
`bin/workflow` now resolves its root through `readlink -f` like the others.
Migration `1791073344-public-commands-bin` repoints checkout `~/.local/bin` links
and reports (never rewrites) user files found by `scripts/legacy-paths`.

- Verified on umbra: 37 unit tests, including a new `tests/test_layout.py`. It checks
  the links, that no code in the tree calls the compatibility paths, and that the
  migration relinks, reports, leaves user files unchanged and is idempotent.
  `scripts/doctor` passes with the new bin/ checks. qmllint shows no errors.
  After `hyprctl reload` there are no config errors and 231 binds. The shell hot
  reload logged no errors and IPC responds. `titan settings/theme/shell`,
  `bin/workflow toggles` and the `scripts/workflow` compatibility path all work.
  The live migration repointed `~/.local/bin/titan{,-shell}` and found no
  user-file references.
- Not verified: a keypress through a `workflow` binding. Bindings are Lua
  closures, so the command path was checked in source, not inspected live.
  Also untested: the packaged layout in a VM, an upgrade from 0.2.0 with an
  old-path `hypr.lua`, and ISO build/install with the moved `titan-install`.
  All three belong to step 5.

## Layout split step 5: VM verification — 2026-10-03

All runs used the local 0.3.0 build of `6dd8bd2`, one 2 GiB VM at a time.

- `tools/vm-test --graphical --stay` (`run.yFc9LX`): all 19 package checks
  passed, including the new "developer tools are not packaged" check. Both
  graphical checks passed (ReGreet login, first-login setup, live shell). The
  desktop capture showed the Welcome screen over the shell. In the guest,
  `/usr/bin/titan*` resolve into `/usr/share/titan/bin/`, the five
  `scripts/NAME → ../bin/NAME` links exist, `tools/` is absent, and both
  `bin/workflow` and `scripts/workflow` work. The shell log errors were only
  the cloud VM's missing NetworkManager/BlueZ, the same as in earlier runs.
- `tools/vm-build-iso` in that VM built `titan-0.3.0-2026.10.04-x86_64.iso`,
  and its checksum passed. `tools/vm-install-test RUN --recovery`
  (`install.iavM9l`): the ISO's `bin/titan-install` and `install.py` match the
  checkout. Every recovery check passed (failed package step, killed installer
  with a surviving worker, foreign and busy mounts, cancel/wrong disk, confirmed
  recovery), then a fresh UEFI/Btrfs install booted to ReGreet and the shell.
- Upgrade (`run.aWcZ55`): installed the published stable `titan-desktop` 0.2.0
  through the documented steps. Two current checks fail there as expected
  (0.2.0 predates the skill scope and still ships the VM tools). Added a
  `hypr.lua` bind and a user unit that both call `/usr/share/titan/scripts/…`,
  then ran `pacman -U` with the 0.3.0 packages. `/usr/bin/titan` moved to
  `bin/titan`. `titan migrate` applied the mise and bin migrations, listed both
  user files with line numbers without changing them, and a second run reported
  none pending. The old `scripts/workflow` path still works. `titan doctor`
  passes with the legacy-path warning, and the packaged Hyprland config
  verifies. mise was installed as a new dependency and is active in
  interactive Bash.
- Still open: the version
  bump/release, and removing the compatibility links one release later.

## Lock screen diagnosis and QEMU lock test — 2026-10-03

- **Journal evidence (previous boot):** three failed attempts at 03:32:21–03:33:15
  triggered `pam_faillock` ("account temporarily locked"). A later Hyprlock was
  told "temporarily locked out" at 03:35:17. Hyprlock's own output was not
  captured, and there are no hyprlock core dumps. Arch's faillock defaults apply
  (deny 3, fail_interval 900 s, unlock_time 600 s). The first "black screen"
  report therefore at least overlapped a lockout during which the right
  password could not work.
- **Found in QEMU:** Hyprlock 0.9.6 shows PAM's "(N minutes left)" for only about
  2 s. Its input field faded out while empty, so an idle lock showed only the
  clock on `#08090b`. After a lockout expires (tested with a 40 s VM-only
  `unlock_time`) or is reset, the first correct password is still refused with
  a stale message. The attempt began during the lockout, it is not recorded,
  and the second try unlocks. Attempts refused during a lockout add no tally
  record, and the tally clears after expiry.
- **Changes:**
  - `scripts/lock` sends Hyprlock's output to the journal (`-t titan-lock`).
  - The `misc:allow_session_lock_restore` option is on.
  - `hyprlock.conf` keeps the field visible (`fade_on_empty = false`, an
    adaptation for clarity) and adds a `scripts/lock-status` label. The label
    reports the lockout and its remaining minutes, and then the "enter it
    again" hint.
  - New `docs/lock-recovery.md`.
- **QEMU graphical test, extended and passing:** a real Super+Shift+Backspace
  `workflow` binding toggles gaps and back. Super+Ctrl+L renders the lock
  (framebuffer measured, capture inspected: clock, label, field). A
  `kill -KILL` of Hyprlock shows Hyprland's lockdead screen, and the documented
  `hyprctl --instance 0 dispatch` relaunch renders the lock again. Three wrong
  passwords show the red lockout line, the right password stays refused,
  `faillock --reset` follows, and the unlock succeeds on try 2.
- **lock-status cases checked with a fake faillock:** a lockout, failures within
  and beyond `fail_interval`, an ended lockout, and invalid entries.
- **On umbra:** Hyprland reloads without config errors and
  `allow_session_lock_restore` is on. No lock was started on the owner's
  session. Still open: a hands-on Super+Ctrl+L on the Intel laptop, including a
  TTY switch while locked.

## Lock after a console switch (laptop) and lock-rescue — 2026-10-03

- **Owner test:** Super+Ctrl+L showed the clock, label and field, and the password
  unlocked. With the screen locked, switching to a text console and back left
  the lock looking frozen and ignoring typing. The owner restarted greetd from
  tty2, which ended the session.
- **Journal:**
  - The 20:14 lock got four "stray release" key events at the return
    (20:14:22). Three typed passwords then failed (20:14:51–20:15:16),
    `pam_faillock` locked the account, and greetd was restarted at 20:26:21.
  - The 20:28:41 lock logged two "key already pressed" events at 20:28:58,
    and greetd was restarted at 20:29:02.
  - Aquamarine logged "Restoring after VT switch" and restored the CRTC.
    Hyprlock received key events, so input reached it. Hyprland's own logging
    is disabled, so its render and keyboard state are not recorded.
- **QEMU:** not reproduced. Ctrl+Alt+F2, typing on tty2, then Ctrl+Alt+F1 with
  quick QMP keys and with separate slow press/release events: the correct
  password unlocked first time, with no key errors after the return.
- **Leading hypothesis (unconfirmed):** Ctrl/Alt state is lost across the
  switch on real hardware, so typed letters arrive as shortcuts (no dots, wrong
  password). Verbose Hyprland/Hyprlock input logging was deliberately not
  enabled, because it could record the password.
- **Added `scripts/lock-rescue`** for use from a TTY:
  - It saves a lock screenshot (grim works from outside the session while
    locked; verified in QEMU), Hyprlock's journal, the process state, Caps
    Lock, the faillock tally and the sessions. It never records keys.
  - It then replaces Hyprlock in the same session.
  - The QEMU graphical test now uses it for the restore stage. A fresh VM
    passed all 19 package checks and 7 graphical/lock checks.

## Cause of the post-console-switch freeze; vt-redraw — 2026-10-03

- **Owner run 3** (with a VT trace recording only `/sys/class/tty/tty0/active`
  changes): locked at 21:01:45, left for tty3 at 21:01:50.927, and returned to
  tty1 at 21:02:00.044. Hyprlock's next output configure came at 21:02:28.033.
  The owner waited 15 s, then typed: dots appeared and the unlock was
  immediate. Run 2: blind password authenticated at 20:59:35, but "Unlocking
  session" waited for the configure at 20:59:40. Aquamarine's log shows
  "Restoring crtc 151" followed by several keystrokes ("palm: keyboard
  timeout") before "Modesetting eDP-1". Conclusion: input works, but Hyprland
  defers the restoring modeset until a frame is requested, and an idle lock
  requests none. The stuck-modifier hypothesis is withdrawn.
- **Fix:** `scripts/vt-redraw`, started by `session-start` and logged with
  `-t titan-vt-redraw`.
  - It waits on sysfs notifications for `tty0/active`, with no polling.
  - When `XDG_VTNR` is active again it runs
    `hl.dsp.force_renderer_reload()`; the dispatcher was confirmed on umbra.
  - It exits when the Hyprland instance directory disappears.
- **QEMU:** the session started vt-redraw automatically, and it fired once on
  the return to tty1, not on leaving. A new graphical stage (Ctrl+Alt+F2 → F1
  while locked: one redraw, rendered lock) passed on a fresh VM, along with
  the other stages.
- **umbra, owner test:** returned to tty1 at 21:18:30.672. vt-redraw fired, and
  Hyprlock's configure arrived at 21:18:30.899, 0.23 s later; it was ~28 s
  before the fix. Dots appeared immediately, and the password unlocked at
  21:18:33. Confirmed.

## Hands-on workflow binding and mise PATH on umbra — 2026-10-03

Closes the two hands-on items left open by the bin/ layout split and the mise
change.

- **workflow keypress:** the owner pressed Super+Shift+Backspace twice. The
  `bin/workflow gaps` binding toggled `workflow.json` and the live layout
  (21:24:17: `gaps=false`, `gaps_in` 5; 21:24:20: `gaps=true`, `gaps_in` 0),
  returning to the owner's no-gaps choice. The binding path through `bin/`
  works from a real key, not only in QEMU.
- **mise shims in the session:** the running Hyprland session started at 20:29,
  after the mise change. A command started through `hl.dsp.exec_cmd`, the
  dispatcher every exec binding uses, received
  `~/.local/share/mise/shims` first on `PATH`, resolved `gh` to the mise shim
  and ran it (2.102.0). Processes Hyprland had already spawned (`vt-redraw`,
  Xwayland) carry the same `PATH`. No Titan binding launches a mise tool
  today; the check used a temporary dispatched command, not a key.
