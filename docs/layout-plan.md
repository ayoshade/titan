# Plan: split `scripts/` into `bin/`, `scripts/` and `tools/`

Status: **approved 2026-10-03; steps 1–4 done** (tools moved, commands in
`bin/`, migration `1791073344-public-commands-bin`, docs). Step 5 (VM tests and a
release) remains. The owner accepted
the recommended answers to the open questions: `workflow` stays off `PATH`,
the folder is `tools/`, compatibility links last one release after `bin/` ships.

## Why

Omarchy keeps every callable command in `bin/` and puts it on `PATH`. Titan
deliberately exposes few commands (`titan`, `titan-shell`, `titan-session`)
that dispatch to helpers and to Python in `lib/titan/`; that stays. The problem
is that `scripts/` mixes three different kinds of file:

- the public, stable interface (commands on `PATH`, plus `workflow`, which
  bindings, the shell and agents call);
- internal helpers the desktop and those commands run;
- developer and release tooling (`build-repo`, `vm-test`, …), which today ships
  to every user in `/usr/share/titan/scripts/` although no installed system
  needs it.

## Target layout

| Directory | Contents | Shipped | On `PATH` |
| --- | --- | --- | --- |
| `bin/` | `titan`, `titan-shell`, `titan-session`, `titan-install`, `workflow` | yes | `titan*` names only |
| `scripts/` | `adjust`, `apply-theme`, `bootstrap`, `doctor`, `fetch-wallpapers`, `install-*` (agent-skills, always-awake, bash-defaults, login, packages, snapshots, workflow), `lock`, `screenshot`, `session-start`, `shell-restart`, `titan-hardware` | yes | no |
| `tools/` | `build-iso`, `build-repo`, `publish-repo`, `vm-build-iso`, `vm-graphical`, `vm-install-test`, `vm-test` | **no** | no |

Rules: `bin/` is the compatibility surface. Renaming or removing anything in it
needs a migration and a deprecation period. `scripts/` may change freely as long
as every caller in the tree is updated. `tools/` only needs a checkout.

Every file stays one directory below the root, so the existing
`root=$(dirname "$(readlink -f "$0")")/..` resolution keeps working unchanged.

`install-login` stays in `scripts/` on purpose: `lib/titan/install.py` runs
`/usr/share/titan/scripts/install-login` inside the target. The installer ISO
and the repository package can differ in version, so that path must not move.

## Reference inventory (from `rg`, 2026-10-03)

Code that must change, not only docs:

- **Paths into `bin/`:** `config/quickshell/umbra/theme/Paths.qml` (`workflow`;
  add `bin(name)` next to `script(name)`), `config/hypr/bindings.lua`
  (`scripts/workflow`), `lib/titan/workflow.py`, `scripts/install-workflow`,
  `scripts/screenshot`, `scripts/session-start`, `bin/titan` (its `workflow` and
  `titan-shell` passthroughs), `scripts/bootstrap` (`~/.local/bin` links),
  `packaging/titan/PKGBUILD` (`/usr/bin` links).
- **Installer:** `tools/build-iso` (installs `titan-install` under
  `/usr/share/titan-installer/scripts/`; move to `.../bin/`), `tools/vm-build-iso`
  (tar list), `tools/vm-install-test`, `tests/test_installer.py`.
- **Tools calling each other:** `vm-test`/`vm-install-test` → `build-repo`,
  `vm-graphical`; `publish-repo` → `build-repo`; `vm-build-iso` → `build-iso`.
- **Docs and skills:** README, AGENTS.md, `docs/{distribution,installation,workflow,keybindings,verification}.md`,
  `agents/skills/*` and the end-user `default/agents/skills/titan/*`
  (`hooks.md` tells users to write units that call `scripts/workflow`).

Unchanged callers (`scripts/` stays): `lock` (Hyprland, hypridle, shell menus),
`session-start` (`hyprland.lua`), `apply-theme`, `shell-restart`, `doctor`,
`install-*`, `fetch-wallpapers`.

## Compatibility

User-owned files outside Git may name the old paths: `~/.config/titan/hypr.lua`,
user systemd units written from `hooks.md`, keybindings or menus that agents
added, and the developer `~/.local/bin` links. None exist on this laptop today
apart from those links, but published 0.2.0 users may have them.

1. Keep **relative compatibility symlinks** `scripts/{titan,titan-shell,titan-session,titan-install,workflow} → ../bin/NAME`
   in the tree and package for at least one release.
2. A migration relinks `~/.local/bin/titan*` that point at `$root/scripts/NAME`
   to `$root/bin/NAME` (the checkout case; packaged installs use `/usr/bin`).
   It **reports** user files that mention `/scripts/{workflow,titan,…}`
   with the replacement path but does not rewrite them.
3. `doctor` warns while such references remain.
4. Remove the compatibility links in a later release, with release notes and a
   final migration that reports anything still pointing at them.

`titan update` from a checkout runs `git pull` while `scripts/titan` is
executing. Git replaces it with a symlink rather than rewriting it, so the
running process keeps reading the old file. This needs to be confirmed in the
VM test.

## Steps (separate commits, each leaving a working desktop)

1. **Move developer tools to `tools/`.** `git mv` the seven files and update
   their cross-references, docs, skills and tests. There is no runtime impact
   on the desktop. The package stops shipping them automatically, because the
   PKGBUILD copies `scripts/` but not `tools/`.
2. **Move the public commands to `bin/`.** `git mv` them, add the
   compatibility symlinks, and update all code callers above. Then update
   `Paths.qml` and the Hyprland bindings, reload Hyprland, and let the
   Quickshell hot reload finish before any IPC test.
3. **Migration and doctor.** Add the relink and report migration, and a
   doctor check. Add a test that `rg` finds no caller in the tree still using
   the compatibility paths.
4. **Docs.** Cover AGENTS.md (repository map, command list), the README layout
   tree, distribution, installation and workflow docs, and both skill sets.
5. **Release.** Bump the version, rebuild the packages and test them in a VM.
   Publish only when the owner asks.

## Validation

- `scripts/doctor`, `bash -n` on every moved script, `qmllint` on the changed
  QML, `Hyprland --verify-config`, live `hyprctl configerrors`.
- Live session: every `workflow` keybinding class (screenshot, clipboard,
  toggles), the lock binding, CommandPanel, the Settings window doctor and
  restart buttons, and `titan theme`/`titan wallpaper`/`titan shell`.
- `titan migrate` twice (idempotent) and `titan migrate --status`.
- `tools/vm-test --full` on the new packages: `/usr/bin` links resolve, the
  compatibility links exist, `tools/` is absent from `/usr/share/titan`, and
  `titan setup` and `titan update` work. Upgrade a VM from the published
  0.2.0 to the new build with a `hypr.lua` that references
  `/usr/share/titan/scripts/workflow`, and confirm it still works and is
  reported.
- `tools/vm-build-iso` and `tools/vm-install-test RUN` (plus `--recovery`), since
  `titan-install` moves inside the ISO.

## Open questions for the owner

1. **Should `workflow` be on `PATH`, for example as `titan-workflow`?** Recommended:
   no for now. Agents and bindings call it by path, and `titan settings` and
   `titan wallpaper` already expose the common parts. It can be added later
   without moving anything.
2. **Name of the tooling folder: `tools/` or `dev/`?** Recommended: `tools/`.
3. **How long to keep the compatibility symlinks?** Recommended: until the release
   after the one that introduces `bin/`.
