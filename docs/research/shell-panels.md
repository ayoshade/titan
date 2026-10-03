# Control center, settings, themes and wallpapers: reference notes

These notes come from frame sampling of saneAspect videos on 2026-10-03; see
[saneaspect-videos.md](saneaspect-videos.md) for review depth. Measurements
are at 1920×1080. Treat any section he never opened as unknown.

## Control center

Sources: 5cp6DkClAuM 0:22–0:41, J8s7O2IGogE 5:26–5:40, Ob98KFByTec 7:55 and
21:15.

- **Shell:** a black outer frame (radius ~36) around a graphite inner surface.
  It is about 514 px wide. In the side-circle layout it drops from the right
  circle at the top edge.
- **Tiles:** two rows of a three-column grid: Wi-Fi, Focus, Lock; then
  Bluetooth, Game Mode, Night light.
  - Pill tiles have a round icon badge that is accent-filled when on, a bold
    title and a muted status line.
  - Lock and Night light are round buttons; Night light fills with the accent
    when on.
- **Cards:** Sound and Display cards each hold a title, a › drill-in button
  and a tall pill slider with the icon inside the fill. A Notifications card
  has "Clear all", app-initial avatars and ✕ buttons. One later version
  replaces a tile with a media card.
- **Drill-in pages** have a back button, a title and a switch:
  - **Wi-Fi:** the connected network with Disconnect; "Networks · Scanning".
  - **Bluetooth:** Saved devices with Connect; "Nearby · Scanning" with a
    pairing hint.
  - **Sound:** Output list with checkmarks and a slider; Input list with a
    slider; per-app sliders.
  - **Display** (J8, 5:36): a card per monitor with brightness, scale chips
    (1.0–2.0×) and resolution; a Night Light toggle.

## Settings window

Sources: nKomstQedmE (most of the video), J8s7O2IGogE 6:15–7:30.

- **Window:** about 806×543, floating and dark.
- **Sidebar:** about 210 px wide, starting with "Search Settings". Ten sections
  each have a round icon: Bar & Island, Media, Clock & Date, Appearance,
  Motion, Launcher, Notifications, Control Center, Lock Screen, System. The
  active row is lighter, with an accent-filled icon.
- **Content:** ← → history buttons, then a hero card with a round icon, title
  and description. Rows are grouped into rounded cards with hairline
  separators and uppercase group labels. Controls are switches, sliders with
  right-aligned values, and text fields.
- **Rows seen:**
  - **Bar & Island:** Notch mode, Notch flare (px), Bar height, Collapsed
    width, Expanded height, Minimum expanded width, Gap from screen edge.
  - **Appearance:** Theme (value →), Wallpaper (Choose… →); Accent colour
    swatches, Custom (#rrggbb), Colour burst; Type (font size, body font,
    display font); Shape & depth (spacing unit, small radius, …).
  - **Motion:** Reduce motion, Movement ms, Fades & colour ms, Hover ms,
    Bounce %.
- **Not shown in any reviewed video:** Media, Clock & Date, Launcher,
  Notifications, Control Center, Lock Screen and System. Titan fills them with
  its own real options.

## Theme and wallpaper switching

Sources: 5cp6DkClAuM 1:50–2:12, J8s7O2IGogE 5:45–6:00 and 7:20–7:30.

- **Theme carousel (top centre):**
  - "Search themes…" with an "n/N" count and "Enter to apply".
  - Cards (~186×98) show six palette dots and the theme id, on the palette's
    own background colour.
  - The selection is centred and outlined in the accent colour, and an accent
    dot marks the applied theme.
- **Wallpaper carousel:**
  - "Wallpaper" on the left, the current theme on the right.
  - Thumbnails with the selection centred, enlarged and accent-outlined; a dot
    marks the applied wallpaper.
  - The file name sits bottom left, "n/N · Enter to apply" bottom right.
- **Wallpaper sets:** each theme has its own wallpapers, and the picker lists
  only the current theme's. Some are palette-recoloured (for example
  `horizon-recolored.png`). Applying a theme switches the wallpaper too.
- **Transition:** the change is a soft fade with a brief blur.

## Wallpaper sourcing

Source: ipEGXS5WcSg (frames). He uses three sources:
- wallhaven.cc (Toplist), which is also shown in ZS6syCYFKPE at 1:30;
- theanimegallery.com;
- r/unixporn posts.

## Launcher and menus

Sources: 5cp6DkClAuM 0:48–0:53, J8s7O2IGogE 5:00.

- **Panel:** a flat black panel about 460 px wide at the top centre. It has no
  inner graphite card.
- **Search:** a magnifier and "Search…", with a hairline divider below.
- **Rows:** compact, about 42 px. Each has a dark rounded icon tile, a bold
  name and a muted description.
- **Selection:** a lighter fill plus a short accent bar at the left edge.
- **Height:** the panel shrinks to its results; one match gives a one-row
  panel.
- **Ranking:** Mcjr5T2pHxw's captions say he studies how OS launchers rank
  results.
- **Unknown:** he never shows a keybindings menu or a command menu, so Titan's
  use the launcher style.

## Power menu, game-mode bar and Display page

- **Power menu:** Mcjr5T2pHxw (captions at 10:02 and 11:54; the course page
  frame at 11:54) describes "a simple power menu in the control center". The
  frame only shows his course's example shell. His actual power-menu layout was
  not visible in any reviewed video.
- **Game Mode:** 5cp6DkClAuM 0:38–0:41 shows the notch becoming a full-width
  black bar with the clock centred, and back.
- **Display page:** the Night Light row has a toggle and a kelvin temperature
  slider (5cp6DkClAuM 0:35).
- **Notifications:** his captions say they follow Windows 11 notifications.
  Grouping of notifications that arrive together is a stated goal, but his
  layout was not visible.

## Notch mode and media popup

- **Notch mode** (ipEGXS5WcSg 1:02, Settings → Bar & Island): the island
  attaches flush to the top edge, and concave "flares" blend it into the edge.
- **Older layout** (Ob98KFByTec 7:30): the left circle shows album art and
  opens a media card with large art on an art-tinted background, plus title,
  artist, album, player, progress and transport.

## Titan implementation checklist

| Item | State |
| --- | --- |
| Control center grid, slider cards, media, notifications | Implemented (`modules/ControlCenter.qml`). It drops below the island's status icons because the Oct 2 layout has no right circle |
| Wi-Fi, Bluetooth, Sound and Display drill-ins | Implemented. Bluetooth pairing still opens `bluetoothctl` for PIN confirmation; Display shows monitor details and brightness, and scale stays on shortcuts |
| Overlay tab strip | Removed; panels stand alone in a black frame with a graphite surface |
| Settings window, sidebar, search, history, hero, grouped rows | Implemented (`modules/SettingsApp.qml`), generated from `theme/settings-schema.json` |
| Settings sections he never showed | Adaptation: Titan options only (clock format, week start, launcher, toast duration, control-center content, lock and idle policy, power profile, maintenance) |
| Colour burst, spacing unit, expanded height and minimum expanded width | Not implemented. The dashboard layout is measured at a fixed 648×167 |
| Theme carousel | Restyled: centred selection, 150 px cards, six dots, accent outline and applied dot |
| Wallpaper carousel, per-theme sets, wallpaper changes with theme | Implemented (`WallpaperSwitcher.qml`, `services/Wallpapers.qml`) |
| Wallpaper transition | Fade with clearing blur (700/900 ms); the timing was judged by eye |
| Palette-recoloured wallpapers | Not implemented |
| Notch mode and flare | Implemented in `Bar.qml`; off by default |
| Album-art media popup | Not implemented; media lives in the dashboard and control center |
| Wallpaper library | `scripts/fetch-wallpapers` (Wallhaven API, colour-matched per theme) |
| Launcher look and behaviour | Implemented (`components/SearchMenu.qml`, `Launcher.qml`): flat panel, divider, icon tiles, accent bar, height follows results |
| Super+Space menus, keybindings | Adaptation: the same SearchMenu; keybindings show key chips. His versions are unknown |
| Session menu | Adaptation: control-center tiles with inline confirmation (`SessionMenu.qml`) |
| Power menu inside the control center | Implemented: the lock button expands Lock, Log out, Reboot and Power off, with confirmation. His exact layout is unknown |
| Game-mode full-width bar | Implemented (`Bar.qml` gameBar) |
| Night light temperature slider | Implemented (`nightlightTemp` setting, Display page and Settings → System) |
| Notifications | Adaptation: avatar cards grouped by app with "+N more"; toast drops below the island |
| Media panel | Implemented after the Ob98KFByTec album-art card, with a blurred art backdrop |
| Lock screen restyle | Not done: Hyprlock reliability is still unverified (see AGENTS.md), and it cannot be tested without locking the session |
