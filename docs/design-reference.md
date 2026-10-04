# SaneAspect reference study — 2026-10-03

Public channel: https://www.youtube.com/@saneAspect/videos

For distribution/workflow behavior and versioned shell APIs, see the local
[agent reference library](research/agent-references.md), including the cloned
Omarchy repository and the owner's Quickshell documentation archive. saneAspect
remains Titan's visual reference.

## Material inspected

- **Why I added a workspace switcher to my Dynamic Island** — October 2,
  2026, https://www.youtube.com/watch?v=J8s7O2IGogE
  Retrieved English automatic captions and inspected sampled video frames.
  The latest form combines workspace marks, clock and status in one small
  centered black pill. The active mark grows; occupied workspaces have a
  lighter shade than empty ones. The expanded shell reuses rounded surfaces.
- **Why I stopped looking at unixporn for Hyprland inspiration** — October 1,
  2026, https://www.youtube.com/watch?v=Mcjr5T2pHxw
  Read the English automatic captions. Focuses on interaction choices,
  notification grouping, launcher ranking and OS control-center designs.
- **A full walkthrough of my Dynamic Island Quickshell** — September 19,
  2026, https://www.youtube.com/watch?v=5cp6DkClAuM
  Inspected frames across the full 137-second visual demo. Its captions are
  music lyrics, rather than a technical explanation. Shows compact circular
  side buttons, rounded control tiles, filled sliders, notifications, theme
  selection, and coordinated translucent windows over a landscape.

This was caption and sampled-frame analysis, not continuous real-time viewing.
Public downloads and captions were kept under /tmp; full transcripts are not
redistributed in this repository. No paid course or proprietary dotfiles were
accessed. No external desktop configuration or source code was copied.

## Notch measurements (2026-10-03)

The compact island was re-measured from native 1080p frames of J8s7O2IGogE and
rebuilt to those dimensions: 230×33 pure-black pill, no border, drop shadow,
glowing active mark, signal bars and solid battery, and no side circles. See
[research/island-notch.md](research/island-notch.md) for measurements and the
deviation checklist, and [research/saneaspect-videos.md](research/saneaspect-videos.md)
for the full channel inventory and review status.

## Panels, settings and wallpapers (2026-10-03)

The control center, Settings window, theme and wallpaper carousels, notch mode
and wallpaper sourcing were studied from frames of 5cp6DkClAuM, J8s7O2IGogE,
Ob98KFByTec, nKomstQedmE and ipEGXS5WcSg. Launcher and menu styling, the power menu inside the control center, the
game-mode bar and the night-light temperature slider followed later the same
day. See [research/shell-panels.md](research/shell-panels.md).

## Toggles, game mode, corners and lock (2026-10-03)

Captions and native frames of OeT5VgeLSIQ and nKomstQedmE added the island's
toggle announcement, game mode's full effect list, Display scale chips and
rounded screen corners; their lock screen, game-bar notifications and motion
system are recorded as open gaps. See
[research/shell-panels.md](research/shell-panels.md#toggles-game-mode-corners-and-lock-screen).

## Current implementation

This summarizes the shell as it is now. The research notes linked above give
the measurements and per-feature checklists.

- **Island** (`modules/Bar.qml`):
  - A 230×33 pure-black pill, 11 px from the top, with glowing workspace marks,
    clock, signal bars and solid battery.
  - Hover widens it slightly; volume and brightness expand it into an OSD.
  - A click opens the dashboard (`IslandDashboard.qml`). The dashboard clock
    morphs it into a month calendar (`IslandCalendar.qml`).
  - Night light and game mode announce themselves inside the pill for ~2 s
    (`components/ToggleIndicator.qml`).
  - Notch mode attaches it to the top edge with flares. Game mode makes it a
    full-width bar. The side circles of the older reference layout were
    removed to match the October 2 video.
- **Control center** (`ControlCenter.qml`):
  - A drop-down below the status icons, built from tiles, slider cards with
    drill-in pages, media, tray, notifications and an inline power menu.
  - Panels use a black frame and graphite inner surface; search menus use the
    reference's flat black launcher style (`components/SearchMenu.qml`).
- **Screen corners** (`ScreenCorners.qml`): black rounded display corners on the
  overlay layer that take no input; hidden in game mode.
- **Settings** (`SettingsApp.qml`): a floating window whose rows come from
  `theme/settings-schema.json`.
- **Theme and wallpaper carousels:** top center, centred selection. Each
  theme owns a wallpaper set, and wallpaper changes crossfade.
- **Colour:** the user's black/graphite direction is kept rather than the
  reference's turquoise or blue accents. Accent choices are the palette's
  own, silver, ice, sage or a custom hex. The Blacksite landscape and all UI
  icons are original.

## Architecture and cost

- **Services and modules:** native reactive services
  (`services/`, `theme/Settings.qml`, `theme/Theme.qml`) stay separate from
  presentation. Shared components are ShellIcon, IconButton, Tile, Switch,
  PillSlider, SearchMenu, WorkspaceMark, SignalBars and BatteryGlyph.
- **Tokens:** Theme derives fonts, radii, motion and island geometry from
  Settings. Preferences and settings use FileView events with atomic writes.
- **Events, not polling:** workspace and window state come from Hyprland
  events.
- **The only timers:**
  - backlight refresh while the control center is open;
  - media position while a media view is open and playing;
  - the debounced night-light re-apply after a temperature change.
- **Wallpapers** are decoded at screen size and blurred only during a
  transition.

Preview images show the original artwork and shell without user applications:
[desktop](previews/desktop.png), [controls](previews/controls.png). They
predate the October redesign.
