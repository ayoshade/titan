---
name: titan-visual-verification
description: Verify visible Titan desktop changes through live UI inspection, matched screenshots, or short recordings. Use for shell layout, styling, focus, transitions, icons, capture flows, login, or boot visuals.
---

# Titan visual verification

Adapted from Omarchy's visual-verification guide. Read the checkout's
`AGENTS.md`, `docs/design-reference.md` and the relevant research checklist.
Automated assertions and saved captures do not replace inspecting the UI.

## Capture the actual changed surface

Record the baseline resolution, scale and relevant user preferences. Capture
the reference and candidate at matched scale. On the live laptop, use a narrow
UI-only region so private windows are excluded:

```sh
grim -g 'X,Y WxH' /path/to/scratch/titan-panel.png
```

Replace the geometry and path with inspected values. Titan's user capture flow
is `bin/workflow capture full` or `capture screenshot`; it saves to
`~/Pictures/Screenshots` **and changes the clipboard**. Prefer direct `grim`
for verification unless the capture/clipboard behavior itself is under test.
Never log clipboard-list or commit screenshots of private applications.

View the captured image using the available image viewer/tool. Inspect bounds,
spacing, radii, type, contrast, icon sizing, focus, clipping and stale state.
Exercise keyboard navigation and the user action producing the changed state;
inspect runtime logs in addition to appearance. A static image cannot verify
motion or interaction.

## Motion and interaction

For timing or transitions, record a short, focused UI-only sequence with an
available Wayland recorder and review frames/playback. Titan's
`bin/workflow capture record` toggles recording: inspect whether
`titan-screenrecord.service` is already active first so you do not stop the
user's recording. Track and stop only a recording you started.

Use QMP input in a disposable VM for compositor shortcuts, login, power/session
boundaries or tests that close apps. Optional typing helpers may exercise a
focused control but do not establish global keybinding behavior. Do not lock,
suspend, log out or reboot the user's session just to finish verification.
Known Hyprlock rendering failures and the laptop's always-awake policy still
apply; report those paths as untested without user-authorized testing.

Close only panels you opened and restore temporary settings to their original
values. For reference-derived visuals, record timestamps and implementation
deviations in `docs/research/island-notch.md` or `shell-panels.md`; update the
video inventory only for material actually reviewed. State exactly what was
inspected, at which scale, and what still needs hands-on hardware checks.
