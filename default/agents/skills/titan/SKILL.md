---
name: titan
description: 'REQUIRED for end-user customization of Linux desktop, window manager, or system config. Use when editing ~/.config/hypr/, ~/.config/titan/, ~/.config/alacritty/, ~/.config/foot/, ~/.config/kitty/, or ~/.config/ghostty/. Triggers: Hyprland, window rules, animations, keybindings, monitors, gaps, borders, blur, opacity, titan-shell, bar, terminal config, themes, background, night light, idle, lock screen, screenshots, reminders, layer rules, workspace settings, display config, and user-facing titan commands. Excludes titan source development through `titan dev link` workflows.'
---

# Customizing a Titan desktop

Titan is an Arch-based desktop: Hyprland (configured in **Lua**) plus a
Quickshell shell called **umbra**, controlled through `titan-shell`.
Customization means changing configuration and settings safely, verifying the
result live, and being able to undo it. Read this file first, then the
reference file for the area you are changing.

| File | Read it for |
| --- | --- |
| [hyprland.md](hyprland.md) | Window rules, layer rules, workspaces, monitors, gaps, borders, blur, opacity, animations, input, keybindings |
| [theming.md](theming.md) | Themes and palettes, accents, wallpapers/background, fonts, radii, terminal colors, GTK, the lock screen's look |
| [capture.md](capture.md) | Screenshots, OCR, color picker, screen recording, where files go |
| [hooks.md](hooks.md) | Running something when an event happens (login, monitor plugged, window opened, theme applied) |
| [plugins.md](plugins.md) | Adding menu entries, shell features, desktop operations and Hyprland plugins |
| [contributing.md](contributing.md) | Turning a customization into a Titan default, plus the commit and documentation rules |

## What exists on this machine (do not assume Omarchy paths)

| Name in a request | What it means on Titan |
| --- | --- |
| `~/.config/hypr/` | Symlink to `~/dotfiles/config/hypr/` (Lua: `hyprland.lua`, `appearance.lua`, `input.lua`, `rules.lua`, `bindings.lua` + `bindings/*.lua`, generated `theme.lua`, `hyprlock.conf`, `hypridle.conf`) |
| `~/.config/kitty/` | Symlink to `~/dotfiles/config/kitty/`. **Kitty is the terminal**; `theme.conf` is generated |
| `~/.config/alacritty/`, `~/.config/foot/`, `~/.config/ghostty/` | Not installed. Say so; don't create configs for terminals that aren't there unless the user installs one (`pacman -Qi alacritty`) |
| `~/.config/titan/` | **The user layer** (never overwritten by updates): `preferences.json` (theme, accent, motion, wallpaper on/off), `settings.json` (Settings window values), `hypr.lua` (Hyprland overrides, loaded last), `kitty.conf` (Kitty overrides). Machine state lives in `~/.local/state/titan/` (`generated/` theme files, `hypr-runtime.lua`, `workflow.json`, `migrations/`) |
| `~/.bashrc`, developer tools | The user's file. Titan appends one marked line sourcing `default/bash/rc`, which activates **mise**, the default tool manager. Install CLIs and runtimes with `mise use -g TOOL` (global, `~/.config/mise/config.toml`) or `mise use TOOL` in a project; prefer it over copying binaries into `~/.local/bin`. Desktop packages still come from pacman |
| `titan-shell` | The desktop shell: island/bar, control center, launcher, menus, notifications, Settings window. Command: `titan-shell status|restart|ipc|functions|log|open|close` |
| "bar" | The **island** at the top centre (it has notch mode and a full-width game-mode bar). Hide or show it: `titan-shell ipc bar` |
| "user-facing titan commands" | `titan` (`version`, `setup`, `migrate`, `update`, `doctor`, `hardware --json`, `theme list|current|ID`, `settings …`, `wallpaper …`, `shell …`), `titan-shell`, and `~/dotfiles/scripts/workflow OPERATION` for everything else |
| `titan dev link` (excluded) | No such workflow exists. Changing Titan's own source or defaults is development: follow `~/dotfiles/AGENTS.md` and [contributing.md](contributing.md), not this file |

**Important:** `~/.config/hypr`, `kitty`, `quickshell` and `gtk-*` are symlinks
into the Git checkout `~/dotfiles`, which holds Titan's **defaults**. Put a
user's personal change in the user layer when one exists (settings, theme,
`~/.config/titan/hypr.lua`, `~/.config/titan/kitty.conf`): it survives
updates and keeps Git clean. Edit tracked defaults only when the change should
apply to every Titan user (see [contributing.md](contributing.md)). Never
`git reset`/`checkout` other people's changes. Commit only when asked.

## Choose the narrowest interface

Prefer earlier rows. They validate input, persist correctly, and are what the
UI uses.

1. **A setting:** `scripts/workflow settings get|set|reset|schema`. This is
   island geometry, notch mode, fonts, radii, motion, clock format, week start,
   launcher, toasts, control-center content and night-light temperature. Values
   are validated against `config/quickshell/umbra/theme/settings-schema.json`
   and applied live; the shell watches `~/.config/titan/settings.json`.
   The Settings window is `titan-shell open settings SECTION`.
2. **An existing operation:** `scripts/workflow …` for themes, wallpaper, gaps,
   transparency, layout, scale, night light, game mode, capture, reminders and
   more (see `~/dotfiles/docs/workflow.md`), or `titan-shell ipc …`.
3. **Hyprland Lua config** for anything those don't cover: rules, binds,
   animations, monitors, input (see [hyprland.md](hyprland.md)).
4. **Shell QML or new workflow code:** only when the user wants new behaviour
   (see [plugins.md](plugins.md)).

Never hand-edit generated files (`~/.local/state/titan/generated/*`,
`~/.local/state/titan/hypr-runtime.lua`). Change
their source instead (see [theming.md](theming.md) and
[hyprland.md](hyprland.md)).

## Machine policy you must respect

- **Always awake:** this laptop deliberately has no idle lock, no display-off
  timer and no suspend. Hypridle is not started; sleep targets are masked. Do
  not re-enable idle, lock or sleep timers unless the user explicitly asks to
  change that policy (`~/dotfiles/docs/always-awake.md`). Manual lock is
  Super+Ctrl+L (`scripts/lock`).
- **Locking:** Hyprlock has had black-screen rendering failures. Do not lock
  the session to "test" a lock-screen change. A successful password check is
  not proof the screen renders; report lock changes as untested until the user
  tries them.
- **Shortcuts:** keybindings exactly mirror Omarchy's chord set (231
  registrations). Do not move existing chords unless asked; check
  `docs/keybindings.md` for conflicts first.
- **Privileges:** no sudo for routine customization. If something truly needs
  root, show the exact command and have the user run it (`! sudo …`); never ask
  for a password in chat.

## Verify every change live

- **Hyprland:** after editing Lua, run `hyprctl reload` and then
  `hyprctl configerrors`, which must print nothing. Check the effect with
  `hyprctl getoption SECTION:KEY -j`, `hyprctl clients -j`,
  `hyprctl monitors -j` or `hyprctl binds -j`. A Lua error can drop the rest
  of the config, so read the errors.
- **Shell (QML):** run `/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml FILE`
  before saving. Quickshell hot-reloads on save, and a syntax error shows an
  error banner live. Don't restart in the same second as a save (that race can
  hang the shell). New IPC functions need `titan-shell restart`. Then check
  `titan-shell status` and
  `titan-shell log | grep -iE "warn|error"`.
- **Scripts:** run `bash -n` (or Python `ast`), then `titan doctor`.
- **Visual checks:** `grim -g "X,Y WxH" /tmp/…png` and look at the image.
  Screenshots of the user's screen can contain private content; keep them in a
  scratch directory and never commit them.
- **IPC:** wrap direct `qs ipc` calls in `timeout 5`; `titan-shell` already
  does this.

## Undo

- **Settings:** `scripts/workflow settings reset KEY`.
- **Theme:** `titan theme PREVIOUS_ID`. Read the current one with
  `titan theme current` *before* changing it.
- **Config files:** they are in Git, so `git -C ~/dotfiles diff FILE` shows
  exactly what you changed. Revert only your own hunks, never the user's.
- **Recovery:** if the shell breaks, Super+Return still opens Kitty, and
  `titan-shell restart` (or `~/dotfiles/scripts/shell-restart` from a TTY)
  recovers it.

## Finish

Tell the user what changed (files and settings), how you verified it (commands
and output, screenshot inspected), how to undo it, and anything not tested
(for example lock screen, multi-monitor, real clicks).
