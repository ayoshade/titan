---
name: titan-migrations
description: Create, change, or troubleshoot Titan's numbered migrations and per-user upgrade markers in a source checkout. Use for existing-install state transitions, not ordinary personal configuration edits.
---

# Titan migrations

Adapted from Omarchy's migrations guide. Read the checkout's `AGENTS.md`,
`docs/distribution.md`, `scripts/titan` and existing migrations first.

Migrations repair existing state that package replacement cannot safely own.
Files live in `migrations/*.sh`; completion is per user in
`${XDG_STATE_HOME:-$HOME/.local/state}/titan/migrations/<filename>`.
`titan migrate` runs pending files in numeric order through Bash and stops on
the first failure. Only successful files receive markers.

`titan update` performs its update and then migration/check steps.
`titan setup` marks migrations complete for a genuinely fresh account and runs
them for an existing account. Titan has no Omarchy login notifier or
`--pending` interface. Inspect without applying through:

```sh
titan migrate --status
```

It prints `done`/`pending` rows; its success exit code does not mean pending
work exists. The session's creation of `setup.log` alone is not an existing
installation.

## Create a repeatable state transition

Use a new numeric prefix such as `<unix-timestamp>-description.sh`; never
rewrite a completed migration to deliver a new transition. Follow Titan's
existing shebang/strict-mode convention: the runner invokes `bash FILE`, so
the migration itself must set `-euo pipefail`. Use `${TITAN_ROOT:?}` for defaults
and respect XDG config/state directories.

- Match the specific old state before changing it. Do not blindly overwrite
  personal files. Back up before replacement and preserve unrelated content.
- Be idempotent after a partial failure and when a second user runs it. Machine
  repairs must detect that another user's run already completed them.
- Keep privilege requirements explicit. Do not add a silent root prompt to
  first-login setup; separate privileged repairs into a reviewed interactive
  operation when needed. Never request credentials in chat.
- A failed prerequisite must return nonzero and keep later migrations pending.
  Do not background the repair or mark completion before work finishes.
- Keep shell lifecycle with the caller; avoid restarting the user's shell from
  a migration. Add documented restart handling if the update requires it.

## Test without changing the owner's markers

Use a temporary HOME plus explicit XDG config/state and CODEX_HOME directories
in the subprocess, not by reassigning the agent's HOME. Stub theme/systemd/
privileged helpers where appropriate. Exercise matching and nonmatching state,
repeat runs, preservation of custom content, and failure ordering. Use QEMU
for privileged machine repairs. Do not delete real completion markers merely
to rerun a test.

Record the version/layout change, recovery path and validation in
`docs/distribution.md` and `docs/verification.md`. Retain shipped migrations
for late updaters.
