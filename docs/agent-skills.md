# Titan agent skills

Titan bundles skills for Codex and Claude under `default/agents/skills/`.
Each directory has a discoverable `SKILL.md` and any required references.
The existing `titan`, `titan-app` and `diagnose-crash` skills remain in place.
The development guides below are available both through automatic skill
selection and the task table in `AGENTS.md`. `CLAUDE.md` remains `@AGENTS.md`.

## Omarchy port inventory

All seven guides in Omarchy's `agents/skills/` were reviewed and adapted from
revision [`8e02fc84f5bdc511ed102e2a14f8935bba4f92bd`](https://github.com/omacom/omarchy/tree/8e02fc84f5bdc511ed102e2a14f8935bba4f92bd/agents/skills)
on its `quattro` branch, retrieved 2026-10-03. The snapshot is pinned for
provenance; this is not a claim of compatibility with every Omarchy release.
The MIT copyright and permission notice are retained in
`default/agents/LICENSE.omarchy` and the installed package's license directory.
Titan's remaining implementation is Apache-2.0.

| Omarchy guide | Titan skill | Adaptation |
| --- | --- | --- |
| `command-metadata.md` | `titan-commands` | Explicit Titan/workflow/shell dispatch, help, typed arguments and documented JSON; no comment metadata scanner |
| `install-scripts.md` | `titan-installation` | Standalone scripts, shared per-user setup, separate privileged templates, package manifests and guarded QEMU installer |
| `shell-dev.md` | `titan-shell-dev` | Existing `umbra` shell root/services/components/modules, settings schema, hot reload and bounded IPC; no imported plugin registry |
| `icon-font.md` | `titan-icons` | Existing original SVG assets, optical sizing and provenance; no private icon font or font tooling |
| `acceptance-tests.md` | `titan-acceptance-tests` | Titan's VM/QMP/ReGreet and installed-disk harnesses; no invented `test/acceptance.d` suite |
| `visual-verification.md` | `titan-visual-verification` | UI-only grim captures, actual inspection, recording ownership, saneAspect research and laptop policy |
| `migrations.md` | `titan-migrations` | Numeric Titan scripts, per-user markers, strict-mode/idempotent repair, real `--status` semantics and first-login boundaries |

The upstream `default/agents/skills/` contains the three end-user skill types
Titan already provides. Those local adaptations were preserved; this port adds
the missing developer guides. No Omarchy binaries, dotfiles, font or desktop
plugin implementation are installed. Guides describe only interfaces that
Titan currently implements and defer to the user's task and repository policy.

## Install and use

```sh
titan skills --dry-run
titan skills
```

Links are created in `${CODEX_HOME:-$HOME/.codex}/skills` and
`~/.claude/skills`, pointing at this installation's bundled skill directories.
Both the source checkout and packaged `/usr/share/titan` installation work.
`titan setup` and `titan update` also attempt skill registration, so fresh and
updating users receive newly bundled skills without manual symlinks.

The installer checks every destination before creating any link. It preserves
matching links and refuses unrelated files, directories or broken foreign
links. A conflict exits 1 without installing new links; setup/update print the
conflict and continue. Inspect the named path and resolve it deliberately,
then rerun `titan skills`. Do not delete a personal skill to make the check pass.
Preview creates no directories or links; invalid arguments exit 2.

New agent sessions discover the linked skills. Examples:

- “Use $titan-shell-dev to add a shell panel.”
- “Use $titan-commands to expose this operation through the CLI.”
- “Use $titan-migrations to move an existing user setting safely.”
- “Use $titan-acceptance-tests to check the greeter in QEMU.”

Source development requires a checkout. The installed skills may inspect
package-owned files, but do not edit `/usr/share/titan` as personal customization.
Use `titan` for settings and user overrides, `titan-app` for a new independent
desktop application, and `diagnose-crash` for an actual coredump.

## Remove or add a skill

To unregister a bundled skill, inspect its links with `readlink` and remove
only those symlinks from the two agent skill directories. This leaves the
bundled source and unrelated personal skills intact. A later setup/update or
`titan skills` registers bundled skills again; persistent opt-outs are not
implemented.

For a new bundled skill, add `default/agents/skills/<name>/SKILL.md`, give it a
narrow name/description, include only relevant supporting resources, and
validate its frontmatter and references. Run `titan skills` to register it.
No second manifest is maintained: the installer discovers skill directories
from their entrypoints. Keep the `AGENTS.md` task table and this inventory
accurate when the developer skill set changes.
