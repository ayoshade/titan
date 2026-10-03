---
name: titan-icons
description: Add or change Titan shell icons, menu icon mappings, or branded marks in the existing SVG asset system. Use for Titan desktop icon development; Titan does not currently ship an Omarchy-style private icon font.
---

# Titan icons and branded marks

Adapted from Omarchy's icon-font guide. Preserve its provenance and optical
verification principles while using Titan's actual SVG implementation.

Read the checkout's `AGENTS.md` and inspect
`config/quickshell/umbra/components/ShellIcon.qml` plus existing assets in
`config/quickshell/umbra/assets/icons/` before drawing or importing an icon.
`ShellIcon.name` resolves `<name>.svg`; menu entries name these assets with
their `icon` value in `config/quickshell/umbra/assets/menus.json`.

Use an existing suitable icon for ordinary actions. Add a brand mark only when
the identity matters; a generic robot should not stand in for several distinct
AI products when users need to tell them apart. Titan has no `titan dev font`
tool or private glyph font, so do not import Omarchy's font or assign imaginary
private-use codepoints.

## Add an asset

- Follow the existing viewBox, stroke widths and optical sizing. Use a readable
  silhouette at the actual menu/button size, preserving counters and negative
  space. Check both selected and unselected appearances.
- Prefer original vector artwork or a licensed official source. Verify the
  source license before importing; record source URL, copyright, license and
  modifications in `NOTICE`, retaining any required license text.
- Match Titan's current monochrome styling. `ShellIcon` uses an `Image`, so it
  does not automatically recolor SVGs through an `iconFont` property. If palette
  recoloring is required, implement and verify it deliberately.
- Update only the intended mapping/call sites and check that every changed
  icon name resolves. Do not replace the established SVG system just to add one
  mark. Editing vector assets does not require image generation.

Parse the SVG, render it at the intended sizes and inspect clipping, stroke
consistency, counters and contrast. Then view the affected live menu/button
following [titan-visual-verification](../titan-visual-verification/SKILL.md).
Keep previews outside
Git and update the appropriate design research checklist for a visual change.
