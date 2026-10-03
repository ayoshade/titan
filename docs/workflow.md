# Titan workflow integration

The chord reference is in [keybindings.md](keybindings.md). Native Hyprland Lua
bindings are separated into six modules under config/hypr/bindings/. Commands
call scripts/workflow, a Bash entrypoint for lib/titan/workflow.py. This module
uses subprocess argument arrays and typed/validated Lua values, never shell
interpolation of user text, filenames or calculator expressions.

## Agent interfaces

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
- `scripts/workflow toggles`: JSON `{"nightlight":BOOL,"gameMode":BOOL}`; safe as
  a diagnostic. `scripts/workflow nightlight` and `game-mode` change the desktop.
  Game mode turns Hyprland animations, blur and shadows off at runtime. It saves
  the previous values in `$XDG_RUNTIME_DIR/titan/game-mode.json` and restores them
  on the next toggle; a Hyprland reload also restores the configured values.
- `scripts/workflow keybindings`, `clipboard-list`, `reminder-list` and
  `worldclock` return JSON arrays for Quickshell. Never dump clipboard-list
  into agent logs: its labels contain user clipboard content.
- `scripts/workflow calculator EXPRESSION`: bounded arithmetic parser supporting
  numbers, parentheses, + - * / // % **, pi and e; no Python evaluation or calls.
- `scripts/workflow app NAME`: installed native applications/TUIs and exact
  reference web-app URLs. Launching an absent optional command produces a notice.
- `scripts/workflow layout`, `width save|restore`, `pop`, `tiled-fullscreen`,
  `transparency`, `gaps`, `square`, `desktop` and `scale up|down` implement
  compositor operations. These change the desktop; do not run them as diagnostics.
- `scripts/workflow capture screenshot|full|record|color|text`: Wayland capture.
  `scripts/screenshot region|full` delegates to this shared implementation.
- `scripts/workflow pick`: select geometry without taking a screenshot.
  The helper owns its slurp PID; selection handlers affect that process only.
  Enter chooses the highlighted window, Ctrl+Enter the monitor, Tab/Ctrl+Tab
  cycle windows, and arrows choose a neighboring window. Dynamic bindings last
  only while a selection layer exists and are removed by their own handles.
- `scripts/workflow reminder-set '20 Stretch'`: minutes plus text.
  `reminder-list` lists future reminders; `reminder-clear` cancels managed timers.
  Timers survive shell reloads but are transient user-session units: restarting
  the user manager or rebooting does not currently recreate them. This is a
  known lifecycle gap; do not claim durable reminders yet.
- `scripts/workflow clipboard-start` starts an event-driven user service only
  if absent. `clipboard-clear` clears retained history. Store filters sensitive
  clipboard states, caps item size at 1 MiB and clips history to 100 entries.
- `scripts/workflow shell-init` initializes private state before the shell loads.

Quickshell menu data lives in assets/menus.json; emoji data in assets/emojis.json.
Presentation uses CommandPanel.qml and existing shared typography/action tokens.
Processes run only for user actions or while a relevant panel is open. The world
clock formats zoneinfo timestamps on the native minute clock event while visible;
there is no background weather fetch or process polling. Notification and
media/output switching use native Quickshell service state.

## State and reproducibility

`$XDG_STATE_HOME/titan` (default ~/.local/state/titan) holds workflow.json,
hypr-runtime.lua, shell-settings.json and a writer lock. Directory mode is 0700;
atomic replacement files are 0600. Runtime Lua is generated only from validated
workspace numbers, known layouts, monitor connector names and bounded scales.
Ordinary configuration reloads preserve managed runtime overrides. Deleting a
particular override should go through a reviewed state edit/regeneration; avoid
blindly removing all user preferences. Clipboard and picker state live under
$XDG_RUNTIME_DIR/titan, never in Git. Nightlight, recording and clipboard use
named user units, independent of QML panel lifetime. Recording gets SIGINT to
finish its container; pressing Alt+Print again stops the owned recording unit.

Reproduce with install-packages then bootstrap; install-workflow adds dependencies
to an existing install. Both use full pacman upgrades, not partial upgrades.
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
