# Extending Titan: menu entries, shell features, operations, Hyprland plugins

"Plugin" can mean four different things here. Pick the smallest that does the
job.

| Want | Mechanism | Size |
| --- | --- | --- |
| A new entry in Super+Space menus | `assets/menus.json` | Data only |
| A new desktop action, callable from a key, menu and agent | A `bin/workflow` operation | Small Python |
| A new preference the user can change | `theme/settings-schema.json` entry | Data plus one binding |
| A new shell surface or widget | Quickshell QML module | Real code |
| Compositor behaviour Lua can't do | Hyprland plugin | Not set up on Titan |

Paths below are relative to `~/dotfiles/config/quickshell/umbra/` unless they
start with `scripts/` or `lib/`.

## 1. Menu entries (`assets/menus.json`)

Each menu is `"id": {"title": "…", "items": [ … ]}`, optionally with
`"input": "placeholder"` for text-entry menus. Items look like this:

```json
{ "label": "Wallpapers", "detail": "Wallpapers for the current theme", "icon": "image",
  "action": "panel", "value": "wallpapers" }
```

`action` is one of:

| Action | Effect |
| --- | --- |
| `menu` | Open another menu; `value` is its id |
| `panel` | Open a panel: launcher, controls, notifications, themes, wallpapers, media, session |
| `controls` | Open a control-center page: main, wifi, bluetooth, sound, display |
| `settings` | Open the Settings window at a section |
| `bar`, `dnd`, `wallpaper` | Built-in toggles |
| `close` | Close the menu |
| Any `bin/workflow` operation | Run it, with `value` as its argument |

`icon` names an SVG in `assets/icons/`; without one, a default is chosen by
action. Open a menu with `titan-shell ipc menu ID`. Validate the file with
`python3 -m json.tool`. The shell hot-reloads, so check the result visually.

## 2. Workflow operations (`lib/titan/workflow.py`)

Add a function and a branch in `main()`, as `nightlight` and `game-mode` do.

- **Safety:** use argv lists (`run('cmd', arg)`), never shell strings, and
  validate every input.
- **Writing state:** use `atomic()` and `STATE`/`RUNTIME`. Add the operation
  name to the serialized-lock tuple in `__main__` if it writes state.
- **Missing tools:** call `require('tool')` so absent tools show a notice
  instead of a traceback.
- **Wiring:** bind it with `b.task(...)`, add a menu entry with
  `"action": "<op>"`, and document it in `docs/workflow.md`.
- **Check:** `python3 -m py_compile lib/titan/workflow.py`, then
  `scripts/doctor`.

## 3. New settings (`theme/settings-schema.json`)

1. Add a key under `settings`, using the existing types: `bool`, `int` (with
   `min`/`max`/`unit`), `choice` (`options`), `string`, `color` or `map`. Add
   it to a section's `groups[].keys`; the Settings window then renders it
   automatically.
2. Read it in QML as `Settings.values.KEY` (import `"../theme"`). Add a
   `Theme` token if it is a design token.
3. `bin/workflow settings get|set KEY` works immediately, because it reads
   the same schema.

## 4. Quickshell (titan-shell) modules

Layout:

| Path | Holds |
| --- | --- |
| `shell.qml` | Root, IPC handler and per-screen `Variants` |
| `services/` | Singletons: state and integrations, registered in `services/qmldir` |
| `components/` | Reusable widgets (Tile, Switch, PillSlider, SearchMenu, …) |
| `modules/` | Surfaces (Bar, IslandDashboard, ControlCenter, SettingsApp, …) |
| `theme/` | Theme and Settings singletons, palettes, schema |

Rules:

- **Reuse first:** reuse components and `Theme` tokens (colours, radii,
  `Theme.movement`, `Theme.duration`). Don't hard-code colours or durations.
- **New panel:** add it to the Overlay `source` mapping and give it a
  `UiState.toggle("name")` path. Expose it over IPC in `shell.qml`
  (`function name(): void { … }`), then `titan-shell restart`, because new IPC
  functions need a real restart.
- **New per-screen window:** add a `Variants { model: Quickshell.screens; … }`
  in `shell.qml`. Use the `umbra-…` namespace convention for layer rules.
- **Prefer events over polling:** use native Quickshell services (Hyprland,
  Pipewire, UPower, Mpris, Networking, Bluetooth, Notifications, SystemTray).
  A `Timer` must be bounded and run only while visible.
- **Accessibility:** give buttons `Accessible.role` and `Accessible.name`;
  keyboard navigation and Escape should work.
- **Before saving:** run `qmllint`. Wait for the hot reload, check
  `titan-shell log | grep -iE "warn|error"`, then capture a screenshot of the
  surface and look at it.
- **QML pitfalls seen in this codebase:**
  - An `id` that shadows a property name (`id: count` inside a ListView broke
    `count`).
  - A `default property alias` swallowing a component's own children.
  - Fractional `font.pixelSize`, which must be an int.
  - `parent.parent` chains; use ids.

## 5. Hyprland plugins

`hyprpm` is **not installed**, and Titan ships no compiled plugins. Most
"plugin" requests (scrolling layout, overview-like behaviour, gestures, window
effects) are covered by built-in Lua features:

- The `scrolling` layout via `hl.workspace_rule` or Super+L.
- `hl.gesture`, `hl.layer_rule` and animations.

If the user really wants a plugin:

1. Install `hyprpm` from the Hyprland packages. That is a system package, so
   show the command and have the user run it.
2. Confirm the plugin supports this Hyprland version (`hyprctl version`) and
   the **Lua** config.
3. Load it explicitly and document it in `docs/`.

Plugins run inside the compositor; a broken one can crash the session, so keep
a way to disable it from a TTY.
