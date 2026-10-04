# Titan workflow integration

The chord reference is in [keybindings.md](keybindings.md). Native Hyprland Lua
bindings are separated into six modules under config/hypr/bindings/. Commands
call bin/workflow, a Bash entrypoint for lib/titan/workflow.py. This module
uses subprocess argument arrays and typed/validated Lua values, never shell
interpolation of user text, filenames or calculator expressions.

## Agent interfaces

Additional original modular operations (defaults, launchers, web apps,
packages, development/service recipes, dotfile recovery, fonts, hooks,
utilities, media, hardware controls and optional QML plugins) are documented
in [operations.md](operations.md). Super+Space's Install/Setup/Remove lists use
the same catalogs and CLI routes. Reference paths and version checks are in
[the agent reference library](research/agent-references.md); remaining parity
work is tracked in [the Omarchy ledger](research/omarchy.md).

- `titan version|setup|migrate|update|doctor|hardware|skills|theme|settings|wallpaper|shell`
  (`bin/titan`) is the top-level command. `titan doctor` (`scripts/doctor`)
  always fails on static errors: scripts, Python, Hyprland config, and live
  `configerrors`. In a checkout it also requires the package set and
  `~/.config` links. On packaged installs missing packages, `titan setup` and
  optional services are warnings. `titan setup` is safe to repeat;
  `titan update` needs the user (sudo).
- `titan skills [--dry-run]`: link the three end-user skills from
  `default/agents/skills/` into
  `${CODEX_HOME:-$HOME/.codex}/skills` and `~/.claude/skills`. Preflight all
  destinations before writing; unrelated files/directories and broken foreign
  links cause exit 1 and no new links. Matching links are left alone. Invalid
  arguments exit 2. Setup/update warn on conflicts and continue. See
  [agent-skills.md](agent-skills.md). Repository development guides live in
  `agents/skills/`; this command does not register them.
- `titan hardware --json`: versioned read-only CPU/GPU/laptop inventory and
  conservative installer package selection. `--packages` prints package names
  and exits nonzero for unsupported GPU profiles. It never installs packages
  or changes configuration. Installer/ISO commands and their QEMU-only apply
  boundary are described in [installation.md](installation.md).
- `titan-shell ipc welcome` opens the first-login Welcome screen.
- `bin/titan-install --status [--json]`: schema-1 read-only JSON with the
  last installation checkpoint, operation lock state and target mounts.
  `--recover --disk DEVICE` confirms verified unmount/empty-marker cleanup in
  the same live UEFI QEMU boot. It preserves partial disk contents; a subsequent
  `--apply` requires a new erase confirmation. These actions are exclusive;
  `--json` is limited to inspection. Exit 1 on refusal/failure, 2 on invalid
  arguments, 130 on interruption. See [installation.md](installation.md).
- `titan-shell status|restart|ipc METHOD [ARG…]|functions|log [-f]|open PANEL|close`
  (`bin/titan-shell`, linked into `~/.local/bin` by `scripts/bootstrap`) is
  the user-facing shell command. Its IPC calls time out after 5 s, and `status`
  exits 1 when the shell is unresponsive.
- `qs -c umbra ipc call shell status`: JSON status, current menu/panel and bar.
- `qs -c umbra ipc call shell menu NAME`: root, apps, system, capture, toggle,
  hardware, background, share, agent, clipboard, emojis, keybindings, calculator,
  reminder, reminders, transcode, weather, worldclock, tmux-help or herdr-help.
- Existing IPC: launcher, themes, theme ID, controls, connectivity, notifications,
  media, clock, appearance, session, close, osd volume/brightness.
- New IPC: bar, setBar BOOL, dnd, dismissOne, dismissAll, invokeLast,
  cycleAudio, cycleMedia and panelAt INDEX.
- `qs -c umbra ipc call shell island`: toggle the expanded island dashboard on
  the focused monitor. `clock` (and `panelAt 3`) toggles the island's calendar
  view; the overlay clock panel was removed. Escape or moving the pointer away closes it.
- `qs -c umbra ipc call shell settings SECTION` opens Titan Settings (island,
  media, clock, appearance, motion, launcher, notifications, control, lock,
  system); `wallpapers` opens the wallpaper carousel. Quickshell hot-reloads
  QML edits, but newly added IPC functions need `scripts/shell-restart`.
- `bin/workflow settings get [KEY]`, `set KEY VALUE`, `reset KEY` and
  `schema`: the same validated settings the Settings window edits (schema in
  `config/quickshell/umbra/theme/settings-schema.json`, values in
  `~/.config/titan/settings.json`). The shell reloads them live. Invalid
  values exit non-zero without writing.
- `bin/workflow wallpaper list|current|next|set PATH`: wallpapers of the
  current theme (JSON for `list`). `scripts/fetch-wallpapers` fills
  `~/Pictures/Wallpapers/<theme>/` from Wallhaven; it uses the network, so
  run it only when asked.
- `bin/workflow toggles`: JSON `{"nightlight":BOOL,"gameMode":BOOL}`; safe as
  a diagnostic, and it refreshes `$XDG_RUNTIME_DIR/titan/toggles.json`, which the
  shell watches. `bin/workflow nightlight [toggle|on|off|apply]` and
  `game-mode` change the desktop. Night light uses the `nightlightTemp` setting
  (kelvin); `apply` restarts it at the new temperature only if it is on.
  Game mode turns Hyprland animations, blur, shadows, window rounding and
  borders off at runtime. It saves the previous values in
  `$XDG_RUNTIME_DIR/titan/game-mode.json` and restores them on the next toggle; a
  Hyprland reload also restores the configured values. While the shell runs,
  the island announces either toggle for about 2 s (from keys, panels or agents
  alike), so these commands send no desktop notification; without the shell they
  still do.
- `bin/workflow keybindings`, `clipboard-list`, `reminder-list` and
  `worldclock` return JSON arrays for Quickshell. Never dump clipboard-list
  into agent logs: its labels contain user clipboard content.
- `bin/workflow calculator EXPRESSION`: bounded arithmetic parser supporting
  numbers, parentheses, + - * / // % **, pi and e; no Python evaluation or calls.
- `bin/workflow app NAME`: installed native applications/TUIs and exact
  reference web-app URLs. Launching an absent optional command produces a notice.
- `bin/workflow layout`, `width save|restore`, `pop`, `tiled-fullscreen`,
  `transparency`, `gaps`, `square`, `desktop` and `scale up|down` implement
  compositor operations. These change the desktop; do not run them as diagnostics.
- `bin/workflow scale list` is read-only JSON: each monitor's name, size, current
  scale and the 1.0–2.0× scales offered by the Display page, snapped to values
  that divide the panel cleanly (a 1366×768 panel offers only 1.0 and 2.0).
  `scale set MONITOR VALUE` applies one of those (or a Super+/ step) and saves it
  in `hypr-runtime.lua`; other values are refused with the allowed list.
- `bin/workflow capture screenshot|full|record|color|text`: Wayland capture.
  `scripts/screenshot region|full` delegates to this shared implementation.
- `bin/workflow pick`: select geometry without taking a screenshot.
  The helper owns its slurp PID; selection handlers affect that process only.
  Enter chooses the highlighted window, Ctrl+Enter the monitor, Tab/Ctrl+Tab
  cycle windows, and arrows choose a neighboring window. Dynamic bindings last
  only while a selection layer exists and are removed by their own handles.
- `bin/workflow reminder-set '20 Stretch'`: minutes plus text.
  `reminder-list` lists future reminders; `reminder-clear` cancels managed timers.
  Timers survive shell reloads but are transient user-session units: restarting
  the user manager or rebooting does not currently recreate them. This is a
  known lifecycle gap; do not claim durable reminders yet.
- `bin/workflow clipboard-start` starts an event-driven user service only
  if absent. `clipboard-clear` clears retained history. Store filters sensitive
  clipboard states, caps item size at 1 MiB and clips history to 100 entries.
- `bin/workflow shell-init` initializes private state before the shell loads.

Quickshell menu data lives in assets/menus.json; emoji data in assets/emojis.json.
Presentation uses CommandPanel.qml and existing shared typography/action tokens.
Processes run only for user actions or while a relevant panel is open. The world
clock formats zoneinfo timestamps on the native minute clock event while visible;
there is no background weather fetch or process polling. Notification and
media/output switching use native Quickshell service state.

## State and reproducibility

User choices live in `~/.config/titan` (`preferences.json`, `settings.json`,
`hypr.lua`, `kitty.conf`; see docs/distribution.md). `$XDG_STATE_HOME/titan`
(default ~/.local/state/titan) holds machine state:
- `workflow.json`, `hypr-runtime.lua` and `shell-settings.json`;
- `generated/` theme files and `migrations/` markers;
- `setup-version` and `welcome-done`;
- writer and update locks.

Directory mode is 0700;
atomic replacement files are 0600. Runtime Lua is generated only from validated
workspace numbers, known layouts, monitor connector names and bounded scales.
Ordinary configuration reloads preserve managed runtime overrides. Deleting a
particular override should go through a reviewed state edit/regeneration; avoid
blindly removing all user preferences. Clipboard and picker state live under
$XDG_RUNTIME_DIR/titan, never in Git. Nightlight, recording and clipboard use
named user units, independent of QML panel lifetime. Recording gets SIGINT to
finish its container; pressing Alt+Print again stops the owned recording unit.

Reproduce with install-packages then bootstrap (checkout), or install the
`titan-desktop` package; install-workflow adds dependencies to an existing
install. Both use full pacman upgrades, not partial upgrades.
Desktop tools come from official Arch repositories. Optional Omarchy app bundles
and Omarchy's external shell/helpers are not installed.

## Known limits

Shared Titan controls replace several separate Omarchy panels. Background/share/
weather/calculator interfaces are original practical equivalents. Optional apps
and service accounts require separate setup. Clipboard paste is explicit after
selection. Region selection is live rather than frozen; heavily overlapping
windows may require pointer selection. Recording/OCR/webcam and multi-monitor
behavior still need hands-on validation; only picker geometry and lifetime were
exercised against the live desktop. Never validate lock/sleep/power/bulk-close by
executing it on the user's working session.

## Experimental boot management

`titan boot status [--json]` reads the installer bootloader choice and generated
file presence without mutation (schema 1). `snapshot_preview_supported` reports
the Limine preview capability, `snapshot_boot` reports a published manifest's
presence, and `snapshot_restore_supported` remains false. These are inventory
fields, not a guarantee that every historical entry has been booted.
`titan boot refresh` is the Bash Limine generator for fresh UEFI QEMU Titan
installations. It requires root, validates the installed root/ESP and retains
changed output files as `.previous`. It cannot migrate the laptop's bootloader.
See [installation](installation.md#opt-in-limine-in-a-fresh-vm) for selection,
supported kernels and appearance overrides. `titan snapshot list [--json]`
reads the preview manifests; `sudo titan snapshot create [--description TEXT]`
captures a read-only Btrfs root and matching boot assets in a fresh Limine VM.
Select the temporary recovery preview in Limine; it uses a text session and
discards writes on reboot. See [snapshots](snapshots.md#experimental-limine-recovery-previews)
for scope and limitations. No automatic reboot or restore is performed.
