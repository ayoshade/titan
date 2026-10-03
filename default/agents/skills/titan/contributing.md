# Customization vs contributing to Titan

This skill is for **end-user customization**. Changing Titan itself (its
defaults, shell source, installers, package lists, release) is development,
governed by `~/dotfiles/AGENTS.md`. There is no `titan dev link` workflow. On
this machine the personal checkout `~/dotfiles` *is* the live config (through
symlinks), so both kinds of change touch the same files. The difference is
intent and how much care the change needs.

## Which one is it?

| Personal customization (stay in this skill) | Titan development (read AGENTS.md first) |
| --- | --- |
| Change a setting, theme, wallpaper, gap, rule or bind for this user | Change a default every Titan user would get |
| Add a window rule for an app this user runs | Add or rename a workflow operation, IPC function or settings-schema key |
| Restyle within existing tokens | Add QML modules, services or components |
| Add a menu entry pointing at an existing action | Change `scripts/bootstrap`, installers, `packages/`, `system/` templates |
| Write a user systemd unit or hook | Anything touching login, locking, power policy or security |

If a request starts as a customization but needs a new interface (for example
"make my terminal follow themes" for a newly installed Ghostty), say so. Then
do it as a Titan change: add the generator to `scripts/apply-theme` rather than
a one-off file.

## Rules that apply either way

- **Inspect before editing:** `git -C ~/dotfiles status --short` and
  `git -C ~/dotfiles diff`. User choices live in `~/.config/titan`, so a clean
  checkout is normal; any local change you didn't make belongs to the user or
  another agent. **Never reset, checkout or stash it.** Stage only files you
  changed.
- **Changing the layout of existing installs** (moving a file, renaming a
  setting): add a numbered, idempotent script to `migrations/` (name
  `$(date +%s)-what.sh`, using `TITAN_ROOT`, never deleting user data without a
  copy), run `titan migrate`, and bump `version`. See `docs/distribution.md`.
- **Another agent:** Codex may be working in the same checkout. Preserve
  unfamiliar changes, and ask before editing a file someone else has modified.
- **Committing:** commit only when the user asks, or when the task is clearly a
  Titan change in a session where they asked for commits.
  - One focused commit per change. The subject is imperative and says what and
    why; the body explains reasons and verification.
  - Never commit screenshots of the user's screen, wallpapers,
    `~/.local/state` files, secrets or clipboard contents.
  - **Push only when asked**; it publishes to `github.com/ayoshade/titan`.
- **Defaults vs user state:** distribution defaults go in the repo (schema
  defaults, palettes, config files). User values belong in
  `~/.local/state/titan/` or `~/Pictures/Wallpapers/`, outside Git.
  - Don't bake a user's personal value into a default unless they say it
    should be Titan's default.
  - Machine-specific values (monitor names like `eDP-1`, the `intel_backlight`
    device) belong in hardware profiles or detection, not in generic defaults.
- **No new dependency without asking.** If one is accepted, add it to the right
  `packages/*.txt` manifest and give the workflow a `require()` notice.

## Validation checklist

Run what applies and report the results honestly; failing checks are reported,
not hidden.

| Area | Check |
| --- | --- |
| Repo | `~/dotfiles/scripts/doctor` (exit 0) and `git diff --check` |
| Hyprland | `hyprctl reload` then `hyprctl configerrors` (empty) |
| Shell | `qmllint`, `titan-shell status`, and `titan-shell log` free of new warnings; a screenshot of the affected surface |
| Python | `python3 -m py_compile lib/titan/workflow.py` |
| Bash | `bash -n` on changed scripts |
| Behaviour | Exercise it: apply and then restore a theme, toggle on and off, set and reset a setting. Restore the user's previous state afterwards |

What needs the user's hands: real clicks, the lock screen, multi-monitor,
suspend/resume (disabled by policy), audio devices. Say exactly which of these
you could not test.

## Documentation to update with a Titan change

| Changed | Update |
| --- | --- |
| Keybinding | `config/hypr/keybindings.json` and `docs/keybindings.md` |
| Workflow operation, IPC, settings, files | `docs/workflow.md` |
| User-visible behaviour | `README.md` (usage) |
| Verification | `docs/verification.md` (dated section: what was checked, what wasn't) |
| Visual change modelled on saneAspect | `docs/research/island-notch.md` or `docs/research/shell-panels.md` checklist, and `docs/research/saneaspect-videos.md` for videos reviewed |
| New commands, paths, architecture or agent rules | `AGENTS.md` (`CLAUDE.md` only contains `@AGENTS.md`) |
| This skill's facts | The relevant file here, so future agents aren't misled |

## Skills in this repo

Skills live in `~/dotfiles/default/agents/skills/<name>/` and are symlinked into
`~/.claude/skills/` and `~/.codex/skills/`. Edit them in the repo; the links
pick the changes up. A new skill needs its own link in both places.

Quote a skill's `description:` in single quotes (doubling any `'`), because
trigger lists contain `: `, which is invalid in a plain YAML scalar; GitHub
reports "mapping values are not allowed". Check with a YAML parser before
committing.
