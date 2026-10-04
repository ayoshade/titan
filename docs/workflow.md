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
- `titan update check [--json] [--no-system]`: read-only local readiness;
  schema 1 reports `ready`, `system`, root free/minimum bytes and a `checks`
  array of `{id,status,message}`. It checks command dependencies, installed jq,
  pacman's database/lock, at least 2 GiB on `/`, the update lock, state storage
  and tracked checkout changes (including linked worktrees). Snapshot and
  missing-upstream warnings do not block. It creates no Titan state, acquires
  no privileges and does not fetch remotes or refresh package databases.
  Exit 0 ready, 1 blocked, 2 invalid arguments. Text checks work without jq;
  JSON output requires it. Readiness is rechecked under the execution lock.
- `titan update status [--json]`: inspect the last attempt and lock, without
  writing. Schema 1 reports `status`, `stage`, `exit_code` and `busy`; an attempt
  adds `pid`, `started_at`, `updated_at` and `system`. No record means `idle`.
  A saved `running` record with no held lock is returned as `interrupted`;
  inspection leaves its bytes unchanged. Failed/interrupted attempts include
  recovery guidance. Successful inspection exits 0 even for a failed attempt;
  unreadable/invalid state exits 1, invalid arguments 2. It requires jq/flock.
- `titan update [--no-system]` saves atomic 0600 stage records in
  `$XDG_STATE_HOME/titan/update.json`: snapshot, checkout, packages (unless
  skipped), migrations, skills, doctor, shell, hooks and complete. Failures
  stop later required stages and retain the command's exit code; a failed
  doctor exits 1 instead of announcing success. INT/TERM record 130/143;
  SIGKILL is detected by later status inspection. The update lock is inherited
  by ordinary workers; privileged pacman also owns its separate database lock.
  Inspect a failed transaction before retrying. There is no automatic resume,
  lock deletion, transaction detachment, reboot or added cleanup operation.
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
- `titan cmd present|missing COMMAND…`: silent literal dependency predicates;
  exit 0 means true, 1 false, 2 invalid arguments. No commands are executed.
- `titan battery`, `network`, `bluetooth`, `power` and `audio` use original Bash
  in `lib/titan/system_status.sh` through `scripts/titan-system`; direct Python
  CLI callers delegate to the same routes. Battery returns schema-1 `batteries`
  and `power` arrays; network status returns schema-1 `devices` containing only
  `device`, `type` and `state`, decoding nmcli's escaped separators. Inspection
  creates no Titan state. Noninteractive tool calls have a 30-second timeout
  with a further 5-second termination bound; `network edit` and `bluetooth pair`
  inherit the terminal and remain interactive. `network qr` displays credentials
  only when explicitly invoked, through nmcli's inherited terminal output.
  Audio volume remains capped at 100 percent; default node IDs must be positive.
  Power changes respect the always-awake/Performance marker and native available
  profiles/Polkit authorization. `powerprofilesctl` requires Arch's optional
  `python-gobject`, now included in Titan's service manifest. Invalid syntax
  returns 2, operation/validation/tool/timeout failures 1, and interruption 130.
  Quickshell continues to own reactive desktop services; no polling is added.
- The whole `titan pkg` family uses original Bash through `scripts/titan-packages`
  and `lib/titan/packages.sh`; direct `desktop_cli.py pkg …` callers delegate there.
  `list` prints the schema-1 bundle catalog; `search QUERY`, `installed` and
  `info PACKAGE…` retain pacman's native output. `add [--plan] PACKAGE…` uses
  `sudo pacman -Syu --needed -- …`. `remove [--plan] PACKAGE…` passes every name
  to `sudo pacman -R -- …`, preserving configuration backups and confirmation.
  `aur [--plan] PACKAGE…` requires an existing paru/yay helper (paru first),
  upgrades Arch before invoking it, and stops if that upgrade fails.
  `bundle NAME [--apply]` returns a schema-1 plan by default; applying validates
  the recipe, required repositories and all executables before any transaction.
  Plans require jq but don't execute package tools or create user state; add,
  remove and bundle plans work without pacman/sudo. AUR plans retain their helper
  requirement; bundle plans retain the paru fallback when no helper exists.
  Invalid arguments exit 2; migrated transaction failures/refusals exit 1.
- `titan pkg present|missing PACKAGE…`: installed-package predicates; 0 true,
  1 false, 2 invalid arguments, 3 unavailable/failed pacman query. Present prints
  requested names on success; missing is silent.
- `titan pkg drop [--plan] PACKAGE…`: idempotent removal of installed requested
  names, preserving dependencies/configuration backups and pacman's confirmation.
  Plans print requested argv without querying packages. No-op removal needs no sudo.
- `titan pkg last-upgrade [--json]`: latest ALPM upgrade timestamp; schema 1,
  `last_upgrade` is null for an empty readable history. Missing/unreadable log fails.
- `titan pkg cache-prune [--keep N] [--plan]`: explicit paccache cleanup with
  at least two retained versions (2–999); execution requires pacman-contrib/sudo.
- `titan dev tools` and `upgrade [--plan]` use Bash mise wrappers, preserving
  the caller's configuration and release-age policy. Plans need jq and create
  no state. Cleanup/upgrades aren't automatically added to `titan update`.
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
- writer and update locks;
- `update.json`, the most recent update's stages/result, containing no
  subprocess output, credentials or changed checkout filenames.

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
presence, and `snapshot_restore_supported` describes the live-ISO recovery
capability for the Limine layout. These are inventory
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

In the live UEFI QEMU ISO, `titan snapshot list --disk DEVICE [--json]` inspects
the target inventory using read-only mounts and verifies the saved asset hashes.
`titan snapshot restore ID --disk DEVICE` restores
the captured root and matching boot files, retaining the displaced root and
boot outputs. `restore-status --disk DEVICE [--json]` reads the persistent
schema-1 journal with read-only mounts; `restore-resume --disk DEVICE` continues
an interrupted restore, including across live boots. Restore/resume require
exact typed confirmation and preserve separate home/log/cache volumes.
Exit 1 means refusal/failure, 2 invalid arguments and 130 handled interruption.
SIGKILL has the usual process exit status and requires another live boot if
owned mounts remain. No `--yes`, reboot or automatic deletion is provided.
