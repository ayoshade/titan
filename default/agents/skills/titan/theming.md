# Themes, colours, wallpapers and fonts

One palette catalog drives the shell, Kitty and Hyprland borders. Wallpapers
belong to themes. Fonts, radii and motion are settings. Change sources, never
generated files.

`apply-theme` also writes tmux, btop, Neovim palette data, Foot, Ghostty,
Alacritty and Helix colors into machine state. Consumers use copied-once
defaults from `default/config/`; install missing files with `titan config install`.
User configs retain priority. `titan font list|current|set FAMILY` changes the
monospace preference without rewriting application overrides. See
`docs/operations.md` for application and recovery interfaces.

## Pieces and where they live

| Thing | Source of truth | Applied by |
| --- | --- | --- |
| Palettes (9: graphite, gruvbox, gruvbox-material, nord, catppuccin, everforest, horizon, rose-pine, industrial) | `~/dotfiles/config/quickshell/umbra/theme/palettes.json` | `scripts/apply-theme ID` |
| Current theme and accent choice | `~/.config/titan/preferences.json` (`theme`, `accent`, `motion`, `wallpaper`) over `theme/preferences-default.json` | `titan theme ID` and the Settings window |
| Kitty colours | **Generated** `~/.local/state/titan/generated/kitty-theme.conf` (then `~/.config/titan/kitty.conf` overrides) | apply-theme (sends SIGUSR1 to Kitty to reload) |
| Hyprland border colours | **Generated** `~/.local/state/titan/generated/hypr-theme.lua` | apply-theme, then `hyprctl reload` |
| Shell tokens (fonts, radii, motion, island size) | `theme/settings-schema.json` defaults plus `~/.config/titan/settings.json` | `bin/workflow settings set`; applied live |
| Wallpapers | `~/Pictures/Wallpapers/<theme>/` (outside Git) plus the choice in `settings.json` → `wallpapers` map | wallpaper carousel, `bin/workflow wallpaper …` |
| GTK | `config/gtk-3.0`, `config/gtk-4.0` (dark Adwaita) and `gsettings` set by `scripts/bootstrap` | Not themed per palette |

## Switch or inspect the theme

```sh
titan theme current                        # note it first
titan theme nord                           # or: titan-shell ipc theme nord   (same operation)
titan theme list
titan-shell open themes                    # the carousel (Super+Ctrl+Shift+Space)
```

Applying a theme regenerates the two files in `~/.local/state/titan/generated/` and records the choice in `~/.config/titan/preferences.json`; Git is untouched. It
signals Kitty, reloads Hyprland (which also clears a runtime game mode), and
switches the wallpaper to that theme's set. Undo by applying the previous id.

## Accent colour

The accent choices are `theme` (the palette's own), `silver`, `ice`, `sage`
or `custom`.

```sh
titan-shell ipc accent ice                                     # silver | ice | sage
~/dotfiles/bin/workflow settings set accentCustom '"#e0a060"'
```

The UI is Settings → Appearance → Accent. Typing a custom hex there also
selects `custom`. From the CLI, set `accentCustom`; the user then picks the
custom swatch, or you set `"accent": "custom"` in `~/.config/titan/preferences.json` while
preserving its other keys.

## Add or modify a palette

Edit `palettes.json`. Each entry needs: `id` (kebab-case, unique), `label`,
`background`, `shell`, `surface`, `raised`, `border`, `text`, `muted`,
`accent`, `danger` and `swatches` (6 colours: red, green, yellow, blue,
magenta, cyan, used for Kitty's ANSI colours and the theme cards). Optionally
add `notch` to change the island colour (the default is pure black, as in the
reference design).

1. Keep the dark, graphite-first character unless the user asks otherwise.
   Check text/background contrast (≥ 4.5:1 for `text`, ≥ 3:1 for `muted`).
2. Validate: `python3 -m json.tool palettes.json >/dev/null`.
3. Apply it with `scripts/apply-theme NEW_ID` and look at the shell (island,
   `titan-shell open controls`), Kitty and window borders.
4. Optional wallpapers: `scripts/fetch-wallpapers NEW_ID` (network; only when
   asked). It picks the Wallhaven colour nearest the accent by hue.

## Wallpapers / background

```sh
~/dotfiles/bin/workflow wallpaper list            # JSON: theme, current, files
~/dotfiles/bin/workflow wallpaper next
~/dotfiles/bin/workflow wallpaper set ~/Pictures/Wallpapers/nord/x.jpg
titan-shell open wallpapers                           # carousel (Settings → Appearance → Wallpaper)
~/dotfiles/bin/workflow settings set wallpaperEnabled false   # solid theme background
```

- **Per theme:** the choice is stored per theme. Without a choice the first
  file in the folder is used. The bundled `assets/wallpapers/blacksite.svg`
  is selectable under every theme.
- **New images:** a user can drop images (jpg, png, webp) into
  `~/Pictures/Wallpapers/<theme>/`; the shell sees them without a restart.
- **Downloading:** `scripts/fetch-wallpapers [--count N] [THEME…]` downloads
  from Wallhaven's Toplist (SFW). It records each image's page in
  `SOURCES.json`. These images are their authors' work: never commit them to
  Git or redistribute them.
- **Transitions:** changes crossfade while the blur clears; reduced motion
  makes them instant.

## Fonts, size, corners, motion

All of these are settings, validated against the schema and applied live:

```sh
~/dotfiles/bin/workflow settings set bodyFont '"Inter"'        # must be an installed family: fc-list : family | grep -i NAME
~/dotfiles/bin/workflow settings set displayFont '"Inter Display"'
~/dotfiles/bin/workflow settings set fontSize 13               # 10–16
~/dotfiles/bin/workflow settings set cornerRadius 12           # 4–24
~/dotfiles/bin/workflow settings set panelRadius 22            # 10–36
~/dotfiles/bin/workflow settings set reduceMotion true
~/dotfiles/bin/workflow settings schema                        # every key, type, range, label
```

- **Strings:** values are parsed as JSON, so `'"Inter"'` is the unambiguous
  form; a bare word that isn't valid JSON is also taken as a string. Numbers and
  booleans are bare. Out-of-range values exit 1 without writing.
- **Island geometry:** `islandWidth`, `islandHeight`, `islandGap`,
  `notchMode`, `notchFlare`.
- **Kitty's font:** set in `config/kitty/kitty.conf`, not in the theme. Kitty
  reloads it with Ctrl+Shift+F5 or SIGUSR1.

## Terminals

- **Kitty only:** Kitty is the only terminal installed.
  - Its colours are generated: never edit `theme.conf`, edit the palette.
  - Everything else (font, padding, cursor, opacity) goes in `kitty.conf`.
  - Window opacity is better done per app with a window rule, or globally
    with Super+Backspace (`bin/workflow transparency`).
- **Other terminals:** if the user installs Alacritty, foot or Ghostty and
  wants palette colours, extend `scripts/apply-theme` to generate their
  colour file from the same palette. That is a Titan change (see
  [contributing.md](contributing.md)); don't hand-write a static copy that
  would drift.

## Lock screen look

`config/hypr/hyprlock.conf` (hyprlock's own syntax) is currently static: a dark
background, a large `$TIME` label in Inter, a mono caption and an input field.
It does not follow the palette. You may restyle it, but read the warnings in
[hyprland.md](hyprland.md) under *Idle and lock* first: don't lock the session
to test, and report the change as untested.
