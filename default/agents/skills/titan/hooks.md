# Hooks: run something when an event happens

Titan has **no hook directory** yet (no `~/.config/titan/hooks/` even though
`~/.config/titan/` now exists, unlike
Omarchy). Do not invent one. Use the mechanisms below, which already work.
Choose by what the event is.

| "Do X when…" | Use |
| --- | --- |
| …I log in / Hyprland starts | `hl.on("hyprland.start", …)` in Lua, or a line in `scripts/session-start` |
| …a window opens, closes, changes title, goes fullscreen | `hl.on("window.open"…)` and friends |
| …a monitor is plugged in or removed | `hl.on("monitor.added"…)`, `hl.on("monitor.removed"…)` |
| …the workspace changes | `hl.on("workspace.active"…)` |
| …the config reloads (theme applied, edits saved) | `hl.on("config.reloaded"…)` |
| …the theme or a setting changes | systemd user path unit watching `preferences.json` / `settings.json` |
| …night light or game mode changes | Watch `$XDG_RUNTIME_DIR/titan/toggles.json` |
| …at a time / every N minutes | systemd user timer (reminders already use transient ones) |

## Hyprland events (Lua)

`hl.on(EVENT, function(...) … end)` returns a subscription
(`:remove()`, `:is_active()`). Events available in Hyprland 0.56, from the
stubs' `HL.EventName`:

- **Hyprland:** `hyprland.start`, `hyprland.shutdown`
- **Config:** `config.reloaded`, `config.props_refreshed`
- **Monitors:** `monitor.added`, `monitor.removed`, `monitor.focused`,
  `monitor.layout_changed`
- **Workspaces:** `workspace.active`, `workspace.created`,
  `workspace.removed`, `workspace.move_to_monitor`,
  `workspace.special_active`
- **Windows:** `window.open`, `window.open_early`, `window.close`,
  `window.destroy`, `window.kill`, `window.active`, `window.title`,
  `window.class`, `window.fullscreen`, `window.pin`, `window.urgent`,
  `window.move_to_workspace`, `window.update_rules`
- **Layers:** `layer.opened`, `layer.closed`
- **Other:** `keybinds.submap`, `screenshare.state`, `input.keyboard.key`

Where to put them: `config/hypr/rules.lua` holds rules. For more than a couple
of hooks, create `config/hypr/hooks.lua` and add `dofile(base .. "hooks.lua")`
to `hyprland.lua` after the other `dofile` lines. Example:

```lua
-- config/hypr/hooks.lua — user event hooks
hl.on("monitor.added", function(monitor)
  hl.exec_cmd(os.getenv("HOME") .. "/dotfiles/scripts/workflow scale up")   -- example action
end)
```

Rules for hook bodies:
- **Keep them fast and non-blocking:** they run inside the compositor. Use
  `hl.exec_cmd` to launch work instead of looping in Lua.
- **Never block on the shell:** don't call `qs ipc` synchronously (a hung shell
  would stall Hyprland).
- **Validate** with `hyprctl reload` and `hyprctl configerrors`, which must
  print nothing.
- **Inspect payloads first.** Check what a callback receives (its arguments)
  with a temporary `hl.exec_cmd("notify-send …")`. Window and monitor objects
  are documented in the stubs (`HL.Window`, `HL.Monitor`).
- **`window.open` fires very often.** Filter on class or title before doing
  anything expensive.

## Login

`scripts/session-start` runs once per Hyprland session (from `hyprland.start`
in `hyprland.lua`). It imports the environment, starts the polkit agent,
initializes Titan state and clipboard history, and finally `exec`s the shell.

- Add new login steps **before** the final `exec qs …` line.
- Background long-running programs (`cmd &`), or better, give them a systemd
  user unit.
- Keep the always-awake policy: do not start Hypridle here.

## Theme or setting changes (systemd path units)

Titan writes these files atomically (rename into place), which systemd's
`PathChanged=` sees:

- `~/.config/titan/preferences.json`: a theme or
  accent was applied.
- `~/.config/titan/settings.json`: any Settings value changed.
- `$XDG_RUNTIME_DIR/titan/toggles.json`: night light or game mode changed.
  Use `%t/titan/toggles.json` in units.

```ini
# ~/.config/systemd/user/titan-theme-hook.path
[Path]
PathChanged=%h/.config/titan/preferences.json
[Install]
WantedBy=default.target

# ~/.config/systemd/user/titan-theme-hook.service
[Service]
Type=oneshot
ExecStart=%h/.local/bin/my-theme-hook     # the user's script; read the theme id from the JSON
```

Then `systemctl --user daemon-reload && systemctl --user enable --now titan-theme-hook.path`.
Confirm with `systemctl --user status titan-theme-hook.path`, and trigger it by
re-applying the current theme. These unit files are user state outside
`~/dotfiles`. If the hook should ship with Titan, see
[contributing.md](contributing.md).

## What not to do

- **Don't wrap `scripts/apply-theme` or `scripts/workflow`** with
  pre/post logic by editing their callers ad hoc. If the user wants a real
  post-theme hook, propose adding a documented hook point to `apply-theme`
  (a Titan change).
- **Don't add timers that wake the machine** or poll every few seconds.
  Prefer events. If polling is unavoidable, bound the interval and document
  why.
- **Don't put secrets** in hook scripts or unit files.
