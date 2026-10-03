# Hyprland on Titan (Lua configuration)

Titan runs Hyprland 0.56 with a **Lua** config, not `hyprland.conf` syntax. Do
not paste legacy `windowrulev2 = …` or `bind = …` lines; translate them to the
Lua API. Type stubs and the upstream example live in
`/usr/share/hypr/stubs/hl.meta.lua` and `/usr/share/hypr/hyprland.lua`; read
them when unsure of a field name.

## File layout (`~/.config/hypr` → `~/dotfiles/config/hypr`)

| File | Purpose | Edit? |
| --- | --- | --- |
| `hyprland.lua` | Entry point: loads the files below, sets monitors and env, starts `scripts/session-start` on `hyprland.start` | Monitors and env |
| `appearance.lua` | Gaps, borders, rounding, opacity, shadow, blur, animations and curves; ends by loading `theme.lua` | Yes |
| `input.lua` | Keyboard layout, mouse and touchpad, gestures | Yes |
| `rules.lua` | Window, layer and workspace rules (`hl.window_rule`, `hl.layer_rule`, `hl.workspace_rule`) | Yes |
| `bindings.lua` + `bindings/{applications,tiling,utilities,clipboard,media,voxtype}.lua` | Keybindings through helper functions; loads runtime overrides last | Carefully |
| `keybindings.json` | Catalog shown by the Super+K keybindings menu | Keep in sync with binds |
| `theme.lua` | **Generated** border colours from the palette | Never by hand |
| `hyprlock.conf`, `hypridle.conf` | Lock-screen look (classic hyprlang syntax); idle policy file, but Hypridle is not started | See below |
| `~/.local/state/titan/hypr-runtime.lua` | **Generated** runtime overrides (per-workspace layout, gaps toggle, square aspect, monitor scale) written by `scripts/workflow` | Never by hand |

## Core API

```lua
hl.config({ general = { gaps_in = 5, gaps_out = 14, border_size = 1 } })   -- any option, nested tables
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1 })
hl.window_rule({ name = "unique-name", match = { class = "^firefox$" }, float = true, size = { 900, 600 }, center = true })  -- effects: see below
hl.layer_rule({ name = "unique-name", match = { namespace = "^umbra-overlay$" }, blur = true })
hl.workspace_rule({ workspace = "3", layout = "scrolling" })
hl.curve("name", { type = "bezier", points = { {0.2,0.8}, {0.2,1} } })
hl.animation({ leaf = "windows", enabled = true, speed = 2.5, bezier = "name" })
hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }), { description = "…" })
hl.on("window.open", function(window) … end)                  -- see hooks.md
hl.env("NAME", "value"); hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
```

- Read live values with `hyprctl getoption decoration:blur:enabled -j`.
  Option keys follow the stubs' `HL.ConfigKey` list, for example
  `general.gaps_in`, `decoration.rounding`, `decoration.blur.size`.
- Try a change without editing files (lost on reload):
  `hyprctl eval 'hl.config({decoration={rounding=8}})'`. Workflow operations
  use this for live toggles. Make it permanent in the Lua file only once the
  user is happy.
- Dispatchers are `hl.dsp.*`, for example `hl.dsp.focus({workspace="2"})`,
  `hl.dsp.exec_cmd("kitty")`, `hl.dsp.window.close({...})`. Run one ad hoc
  with `hyprctl dispatch 'hl.dsp.…'`.

## Common requests

- **Gaps, borders, rounding, opacity, shadow, blur:** edit the `hl.config`
  block in `appearance.lua` (`general.gaps_in/gaps_out/border_size`,
  `decoration.rounding/active_opacity/inactive_opacity`,
  `decoration.shadow.*`, `decoration.blur.{enabled,size,passes,vibrancy}`).
  Border *colours* come from the theme (see [theming.md](theming.md)); a fixed
  colour in `appearance.lua` would be overridden by `theme.lua`.
  - The Super+Shift+Backspace gaps toggle and per-window transparency toggle
    write runtime overrides. A user who says "gaps keep coming back" may have
    the toggle saved in `workflow.json` (`scripts/workflow gaps` flips it).
- **Animations:** `hl.curve` and `hl.animation` in `appearance.lua`. Leaves
  include `windows`, `fade`, `workspaces`, `layers` and their sub-leaves (see
  the stubs).
  - Game mode (`scripts/workflow game-mode`) turns animations, blur and shadows
    off at runtime and restores the previous values on the next toggle.
  - Shell animations are separate: Settings → Motion
    (`settings set movementMs|fadeMs|hoverMs|bounce|reduceMotion`).
- **Window rules:** add to `rules.lua` with a unique `name`.
  - Verified `match` keys: `class`, `title`, `xwayland`, `float`,
    `fullscreen`, `pin` (regex strings or booleans).
  - Verified effects: `float`, `center`, `size = { W, H }`,
    `move = "X Y"` (expressions such as `monitor_h-120` allowed), `no_focus`
    and `suppress_event`.
  - Other effects follow the Hyprland wiki's window-rule names in snake_case
    (for example `opacity`, `pin`, `workspace`, `rounding`). The stubs don't
    type them, so confirm each with `hyprctl configerrors` and by checking the
    window.
  - Find a window's class and title with `hyprctl clients -j`.
  - Titan's own rule floats the Settings window (`title = "^Titan Settings$"`).
  - A rule returns a handle (`local r = hl.window_rule{…}; r:set_enabled(false)`).
- **Layer rules** (blur or animation for bars, menus and notifications):
  `hl.layer_rule` with `match = { namespace = "…" }`. Typed fields: `blur`,
  `blur_popups`, `ignore_alpha`, `no_anim`, `animation`, `dim_around`, `xray`,
  `order`, `above_lock`, `no_screen_share`. Titan's shell
  namespaces are:

  | Namespace | Surface |
  | --- | --- |
  | `umbra-bar` | The island |
  | `umbra-overlay` | Panels and menus |
  | `umbra-toast` | Notification pop-ups |
  | `umbra-background` | The wallpaper |

  List live layers with `hyprctl layers -j`. The island and panels draw their
  own opaque black frames, so blur mainly affects translucent areas.
- **Workspaces:**
  - `hl.workspace_rule` handles per-workspace layout, gaps, monitor binding
    and default names. Typed fields: `workspace`, `layout`, `layout_opts`,
    `monitor`, `default`, `default_name`, `persistent`, `gaps_in`, `gaps_out`,
    `border_size`, `no_border`, `no_rounding`, `no_shadow`, `decorate`,
    `on_created_empty`.
  - Super+L toggles dwindle/scrolling for the current workspace and stores the
    choice in runtime state (`scripts/workflow layout`).
  - The island shows workspaces 1–10 (at least five marks).
- **Monitors and display:**
  - `hl.monitor` in `hyprland.lua`. The development laptop is `eDP-1`,
    1366×768, scale 1; list connected outputs with `hyprctl monitors -j`.
  - Scale up and down with Super+/ and Super+Alt+/ (`scripts/workflow scale
    up|down`, saved in runtime overrides). Mirroring is
    `scripts/workflow mirror`.
  - Keep monitor names in config only for this machine's profile. Titan aims to
    be portable, so prefer `output = ""` with `mode = "preferred"` defaults.
- **Input:** `input.lua` (`kb_layout`, `follow_mouse`, sensitivity, touchpad
  `natural_scroll`, `tap_to_click`, gestures). The touchpad toggle is
  `scripts/workflow touchpad toggle`.

## Keybindings

Bindings are registered through helpers defined in `bindings.lua`. Use the
`TITAN_ROOT` Lua global for Titan paths, never a hard-coded `~/dotfiles`:

```lua
b.bind(KEY, DESCRIPTION, DISPATCHER, opts)   -- raw dispatcher
b.run(KEY, DESCRIPTION, "command args")      -- hl.dsp.exec_cmd
b.task(KEY, DESCRIPTION, "workflow-op args") -- ~/dotfiles/scripts/workflow …
b.shell(KEY, DESCRIPTION, "ipc-method args") -- qs -c umbra ipc call shell …
```

- **Chords:** keys look like `"SUPER + SHIFT + Return"`; physical codes look
  like `code:10` for 1. Options include `{ locked = true }`, `repeating`,
  `release`, and so on.
- **Where to add:** put a new bind in the matching `bindings/*.lua` module,
  inside its `return function(b) … end`.
- **Conflicts:** check first with `hyprctl binds -j` (or by searching
  `docs/keybindings.md`). Titan mirrors Omarchy's chord set exactly; adding a
  chord Omarchy already uses replaces Titan behaviour the user relies on, so
  ask before overriding.
- **Super+K catalog:** add an entry for the new bind to `keybindings.json`
  (`{"key": "SUPER + X", "description": "…", "release": false}`) and to the
  table in `docs/keybindings.md`, so the menu stays truthful.
- **Verify:** run `hyprctl reload`, then `hyprctl configerrors` (expect empty)
  and `hyprctl binds -j | grep -c description`. Watch the expected count:
  231 with voxtype absent, plus whatever you added.

## Idle and lock (read the policy first)

- **Idle:** this machine is deliberately always awake.
  - `hypridle.conf` exists but Hypridle is not started.
  - Super+Ctrl+I and Super+Ctrl+Delete only explain the policy.
  - Enabling idle lock or display-off is a policy change. Do it only on
    explicit request, and update `docs/always-awake.md`.
- **Lock screen look:** `hyprlock.conf`, in hyprlang syntax: `background`,
  `label` (`$TIME`), `input-field`. `scripts/lock` runs
  `hyprlock --immediate-render --no-fade-in --config …/hyprlock.conf` with a
  single-instance guard.
  - Validate the syntax by reading it carefully. Do **not** lock the session
    to test; Hyprlock has had black-screen failures.
  - Tell the user to try Super+Ctrl+L themselves, and report the change as
    untested until they do.

## Night light

`scripts/workflow nightlight [toggle|on|off|apply]` runs `wlsunset` as the user
unit `titan-nightlight`. Super+Ctrl+N toggles it. Set the temperature (kelvin,
2500–6000) with `scripts/workflow settings set nightlightTemp 4000`; when night
light is on, the shell restarts it at the new temperature. It does not persist
across reboot by design.
