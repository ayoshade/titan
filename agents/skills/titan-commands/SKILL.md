---
name: titan-commands
description: Add or change Titan CLI commands, workflow operations, help text, structured output, or shell IPC routes in the Titan source checkout. Use for command development rather than running an existing customization command.
---

# Titan command interfaces

Adapted from Omarchy's command-metadata guide. Titan uses explicit dispatchers;
comments such as `omarchy:summary` have no effect here.

Find the source root through `titan version` or the current checkout. Read its
`AGENTS.md` and `docs/workflow.md` before editing. Installed defaults under
`/usr/share/titan` are package-owned; develop in a checkout.

The [agent reference library](../../../docs/research/agent-references.md) links
the [Omarchy source clone](/home/shade/.cache/titan/references/omarchy) and the
[Quickshell API archive](/home/shade/.webfetch/quickshell/index.md). Consult the
coverage ledger before rebuilding an existing operation.

## Select the owner

| Interface | Implementation |
| --- | --- |
| `titan COMMAND` | `bin/titan`: top-level dispatch and `usage()` |
| Desktop operations | `bin/workflow`, `lib/titan/workflow.py` |
| Additional user operations | `scripts/titan-*`, `lib/titan/desktop_cli.py`, family modules; see `docs/operations.md` |
| Shell control | `bin/titan-shell`, IPC target `shell` in `config/quickshell/umbra/shell.qml` |
| Settings | `config/quickshell/umbra/theme/settings-schema.json`, consumed by the CLI and Settings UI |
| Menu actions | `config/quickshell/umbra/assets/menus.json` and the existing action handlers |

`bin/` is the public interface (on `PATH` for `titan*` names; `workflow` is
called by path). Helpers go in `scripts/`, developer tooling in `tools/`.
Moving or renaming anything in `bin/` needs a migration and a compatibility
link; see `docs/layout-plan.md`.

Prefer a shared operation called by both UI and CLI. Add a standalone script
only when it has a distinct responsibility. Top-level commands belong in
`bin/titan`; do not invent Omarchy's prefix scanner or an unimplemented
`titan commands --json` interface.

## Keep the contract explicit

- Update dispatch, help and `docs/workflow.md` together. Retain existing routes
  and the `umbra` configuration/IPC name unless a compatibility migration is
  part of the request.
- Keep machine-readable output on stdout and diagnostics on stderr. Use a
  schema version for new structured diagnostic APIs. Return nonzero for invalid
  arguments or failed operations; describe exit codes callers depend on.
- Pass arguments as arrays. Do not interpolate user filenames, expressions or
  labels into shell/Lua source; reuse the workflow's typed value handling.
- Resolve script roots from their own location. QML uses `Paths.root` and
  `Paths.script()`, Lua uses `TITAN_ROOT`. Never assume a checkout under HOME.
- Keep credentials, clipboard labels and private application content out of
  diagnostic output. Read current choices before any temporary changes.

## Verify

Check the changed interpreter's syntax, run `scripts/doctor` and
`git diff --check`, then exercise successful and invalid inputs. For a new IPC
function, allow hot reload to settle, use `scripts/shell-restart`, and verify
the live route through `titan-shell` (which bounds calls with a timeout).
Use a disposable VM for commands that install packages, reset user state or
change the session. Do not execute power/session commands as a smoke test.
