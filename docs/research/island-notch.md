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
| Side buttons removed | Matched. Launcher and controls stay on shortcuts; status and clock clicks open panels |
| Accent colour | Adaptation: follows Titan's palette and accent preference instead of his turquoise/ice |
| Expanded 3-column dashboard | Gap: Titan still expands to the 370×78 media/OSD strip |
| Expand/collapse motion | Not measured yet; the 1 s frame scan missed the transition |
| Scale on 1366×768 | Adaptation: the same logical pixels are used, so the island takes a larger share of a small screen |
