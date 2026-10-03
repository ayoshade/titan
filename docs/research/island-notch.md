# Compact island (notch) — reference measurements

Source: saneAspect, *Why I added a workspace switcher to my Dynamic Island*
(https://www.youtube.com/watch?v=J8s7O2IGogE, 2026-10-02). The 1080p60 video
was downloaded to a scratch directory and was not redistributed. Its frames were
decoded at native 1920×1080, and pixels were measured with a script. Clean
measurement frames are at 10:30–10:55, where the island sits over a flat blue
wallpaper. The frames at 0:02 and 4:45 overlap a dark wallpaper stroke and give
unreliable bounds. Values below are logical pixels at that resolution.

## Compact state (10:30)

| Element | Measurement |
| --- | --- |
| Pill | 230×33, pure `#000000`, fully rounded (radius = h/2), no border; centred, top edge 11 px from screen |
| Shadow | Soft black drop shadow, offset downward ~4 px, fading over ~25 px |
| Side padding | ~20 px from pill edge to first mark / battery tip |
| Workspace marks | Five marks at an 11 px pitch. Active: 9×15 accent capsule with a soft accent glow. Inactive: 7×11 capsules. Occupied: accent at ~40% alpha. Empty: ~10% white |
| Clock | `HH:mm`, centred on the pill, cap height ~12 px (≈16 px Inter-like sans, medium), near-white |
| Signal | Four 3 px bars, bottom-aligned, heights ≈4/7/9/12, accent when lit and dim when unlit |
| Battery | 25×12 body, radius ~4, no outline. Accent fill on a dark track, with a detached 1–2×4 tip |
| Gaps | marks→clock ≈23 px, clock→signal ≈22 px, signal→battery ≈7 px |

The captions (around 4–5 min) say that glow is a deliberate part of his
aesthetic and that it was inspired by the iOS cursor glow. In this version, the
earlier side circles (launcher and avatar on the left, Wi-Fi on the right; see
5cp6DkClAuM) are gone.

## Expanded state (10:36–10:49)

The click-expanded island is about 648×167, with a corner radius of roughly
22–28 px. It has three columns:

- **Left:** the focused window's icon and title, plus a numbered workspace list
  with app icons for each workspace.
- **Centre:** a large clock, a week strip where today is highlighted in accent
  and weekend days are red, and a media row with art, title, artist, progress
  and transport buttons.
- **Right:** a *Status* list (battery and charging state, SSID and strength,
  Bluetooth, volume and mic, notifications) and two pills (*Night light* and
  *Game mode*).

The author calls this state unfinished in the captions, so treat it as
direction, not a spec.

## Titan implementation checklist

| Item | State |
| --- | --- |
| Pill size, top offset, black fill, round ends, no border | Matched; measured live at 230×33, y=11 |
| Drop shadow | Implemented (`RectangularShadow`). It is barely visible on Titan's dark wallpaper, where his blue wallpaper made it obvious |
| Mark sizes, pitch, occupied/empty tones, active glow | Matched; glow strength is tuned by eye |
| Clock size and weight | Matched. Titan renders subpixel colour fringes, while his text is greyscale antialiased |
| Signal bars and solid battery | Matched; Ethernet or no Wi-Fi shows full bars |
| Side buttons removed | Matched. The launcher stays on its shortcut. Clicking the island opens the dashboard; the status icons open controls |
| Accent colour | Adaptation: follows Titan's palette and accent preference instead of his turquoise/ice |
| Expanded 3-column dashboard | Implemented (`modules/IslandDashboard.qml`) at 648×167, radius 30, same column positions; compared with 10:41 at matched scale |
| Dashboard week strip, today box, faded edge days | Matched. Weekend red uses the palette's `danger` colour, which is muted in some palettes |
| Workspace list | Shows five rows plus “+” (first empty workspace). With more than five workspaces, the list follows the active workspace instead of scrolling |
| Hover row highlight, calendar hover box | Implemented |
| Calendar morph | Implemented (`modules/IslandCalendar.qml`). The island reshapes to 336×280 (reference 10:37.67–10:38.0: undershoot to ~332, then settle). It has a locale-first-day six-week grid, ←/→ month buttons, a title that returns to the current month, and wheel or Left/Right month paging. Pointer leave collapses it to the compact pill, as in the reference |
| Status rows | Battery, network (SSID/strength or “Wired”), Bluetooth (device name when connected), volume and mic, notification count. Rows open the matching panel |
| Night light / Game mode | Implemented through `scripts/workflow nightlight` / `game-mode`. Game mode is Titan's own runtime toggle; his implementation has not been reviewed |
| Hover media expansion | Removed. Media now lives in the dashboard, as in the reference |
| Expand/collapse motion | Measured at 30 fps (open 636.1–636.43 s, close 652.67–653.2 s). Implemented as OutBack 330 ms (Titan peaks at ~650 against his 653); close animates height (140 ms), then width (380 ms). A 10 px hover bump is included. Dashboard collapses 350 ms after the pointer leaves |
| Scale on 1366×768 | Adaptation: the same logical pixels are used, so the island takes a larger share of a small screen |
