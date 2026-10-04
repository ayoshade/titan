---
name: titan-shell-dev
description: Develop Titan's Quickshell QML shell, services, components, panels, menus, settings integration, or IPC in a Titan source checkout. Use for shell implementation work rather than ordinary end-user settings changes.
---

# Titan shell development

Adapted from Omarchy's shell-dev guide. Read the checkout's `AGENTS.md`,
`docs/workflow.md` and `docs/design-reference.md` before editing.

Use [the agent reference library](../../../docs/research/agent-references.md):
[Quickshell archive](/home/shade/.webfetch/quickshell/index.md) (v0.3.1 for the
installed runtime) and [Omarchy clone](/home/shade/.cache/titan/references/omarchy).
Read the exact API page from the archive before relying on it; distinguish
upstream behavior from Titan's own architecture.

The desktop is one long-running Quickshell process using configuration `umbra`.
Its root is `config/quickshell/umbra/shell.qml`. Keep screen lifecycle and IPC
there, native reactive integrations in `services/`, reusable UI in
`components/`, presentation in `modules/`, and shared tokens in `theme/`.
Do not spawn another desktop shell for each component or introduce Waybar.

## Titan's integration contract

- Use `Paths.root`/`Paths.script()` for source and command paths. Do not hard-code
  `~/dotfiles` or introduce Omarchy's environment variable.
- `titan-shell` controls the existing shell through the `shell` IPC target.
  Inspect `titan-shell functions` and the root's handlers before adding a route;
  do not copy Omarchy's plugin IPC method names or invent an additional bar target.
- Settings are declared once in `theme/settings-schema.json`; CLI and UI share
  validation. User values are outside Git in `~/.config/titan/`.
- Titan keeps its existing components/modules and menu actions. Optional user
  extensions use Titan's own panel/service manifests and `PluginHost.qml`;
  see [operations](../../../docs/operations.md). Built-in cloning, bar
  replacement and capability sandboxing remain unimplemented. Don't claim
  Omarchy manifest compatibility or sandboxing.
- Prefer native Quickshell services over polling. Bound unavoidable polling and
  stop it when hidden. Keep costly scanning, image work and processes tied to
  visibility or an explicit user action.
- Use shared typography, spacing, colors and motion tokens; support reduced
  motion, keyboard focus and multiple screens. Preserve existing shortcuts.

Use targeted edits around Unicode glyphs so they are not lost. For new icons,
read [titan-icons](../titan-icons/SKILL.md); Titan's shared icons are SVG assets.

## Load and inspect

QML saves hot-reload the user's live shell. Lint a candidate in a scratch file
beside the source with `qmllint` before replacing it so imports still resolve.
Then load the affected panel, inspect runtime logs and `titan-shell status`,
and follow [titan-visual-verification](../titan-visual-verification/SKILL.md)
for visible changes.
Static unresolved-type warnings are not proof of a runtime failure.

Do not race an immediate restart against hot reload. New IPC functions require
`scripts/shell-restart` after reload settles; it handles Quickshell's known
shutdown hang. Bound direct `qs ipc` calls with `timeout`. Run `scripts/doctor`
and `git diff --check`, restore test preferences, and record findings in
`docs/verification.md` and the relevant design research checklist.
