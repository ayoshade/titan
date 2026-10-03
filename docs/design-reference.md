# SaneAspect reference study — 2026-10-03

Public channel: https://www.youtube.com/@saneAspect/videos

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
Ob98KFByTec, nKomstQedmE and ipEGXS5WcSg. See
[research/shell-panels.md](research/shell-panels.md).

## Applied to Umbra

The original full-width text bar has been replaced by a centered black island
(the side circles were removed on 2026-10-03 to match the October 2 video).
Workspaces use glowing vertical marks with occupied/empty shades. Clicking the
island opens the three-column dashboard; compact status icons open controls,
and hardware-key OSDs expand the pill. Panels share a central origin, black outer frame and graphite inner
surface. Controls group radio/focus/power tiles, filled sound/display sliders,
media and recent notifications. Launcher rows include icons and rank name
matches ahead of description matches. Session actions retain confirmation.

The user’s original black/graphite direction is retained instead of reproducing
the reference’s turquoise or blue accents. The Blacksite SVG landscape and UI
icons are original, authored for this laptop. Appearance controls persist a
restrained silver/ice/sage accent, reduced motion and landscape visibility.
They change shell appearance; GTK and terminal retain the coordinated graphite
base. This is a close adaptation of the public visual approach, not an exact
copy of every feature in the paid Dynamite shell.

## Architecture and cost

Existing native reactive services remain separate from presentation. New shared
components are ShellIcon, IconButton and ToggleTile. Theme owns shape, spacing,
font, motion and island/panel constants. Preferences use native FileView events
and atomic writes. The static wallpaper is rendered once as an image texture.
Workspace state comes from Hyprland, with no polling. Backlight’s existing
visible-only refresh remains the one deliberate timer for system state.

Preview images show the original artwork and shell without user applications:
[desktop](previews/desktop.png), [controls](previews/controls.png).

## Theme carousel

The follow-up theme switcher reproduces the October 2 video’s compact top-center
search/card/footer arrangement, palette swatches, selection outline and applied
marker. It has nine dark palette adaptations, filtering, keyboard and pointer
navigation, Enter/double-click application, and saved choice. A single JSON
catalog supplies Quickshell tokens and generated Kitty/Hyprland colors.
Application is explicit; browsing does not rewrite configuration. A native
Process serializes theme application and FileView reacts to saved preferences.
GTK colors and wallpaper remain the established dark base/landscape.
