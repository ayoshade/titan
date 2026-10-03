# Titan as a distribution

Titan started as a personal dotfiles checkout. This document records how it
becomes a distribution other people can install and update without losing
their changes. It also records which parts exist today. Read it before changing
layout, installation or updates.

## Layers

| Layer | Location | Owner | Updates may |
| --- | --- | --- | --- |
| Defaults | The checkout (`~/dotfiles`) today; a package (`/usr/share/titan`) later | Titan | Replace freely |
| User layer | `~/.config/titan/` | The user | Never overwrite. Change only through migrations, and keep a copy when moving data |
| Machine state | `~/.local/state/titan/` | Titan, on this machine | Regenerate |
| Runtime | `$XDG_RUNTIME_DIR/titan/` | The current session | Discard at logout or reboot |

User layer files:

| File | Contents |
| --- | --- |
| `preferences.json` | `theme`, `accent`, `motion`, `wallpaper` (over `config/quickshell/umbra/theme/preferences-default.json`) |
| `settings.json` | Settings-window values validated by `theme/settings-schema.json`, including the per-theme wallpaper map |
| `hypr.lua` | Hyprland overrides, loaded last by `config/hypr/hyprland.lua` |
| `kitty.conf` | Kitty overrides, included after the generated theme |

Machine state:

| Path | Contents |
| --- | --- |
| `generated/kitty-theme.conf`, `generated/hypr-theme.lua` | Written by `scripts/apply-theme` |
| `hypr-runtime.lua`, `workflow.json` | Workflow toggles: per-workspace layout, gaps, scale, reminders |
| `shell-settings.json` | Bar visibility |
| `migrations/` | One empty marker per applied migration |

Elsewhere:

- `~/.config/mimeapps.list` is the user's own file. `bootstrap` copies
  `default/mimeapps.list` once; applications may change it freely.
- Wallpapers live in `~/Pictures/Wallpapers/<theme>/` and are never tracked.

The first migration (`migrations/1791060086-user-layer.sh`) moved this
machine from the old layout. That layout tracked the user's theme in Git,
wrote generated files into the checkout, kept settings in state, and linked
`mimeapps.list` into the repo.

## Version and migrations

- **Version:** `version` holds Titan's version (semantic versioning). Bump the
  minor version for layout or behaviour changes and the patch version for
  fixes. `titan version` prints it with the commit.
- **Migrations:** `migrations/<unix-time>-<what>.sh` are Bash scripts run once,
  in numeric order, by `titan migrate`. A marker is recorded in
  `~/.local/state/titan/migrations/` only after a script succeeds. A failure
  stops the run, so later migrations never run on top of a broken one.
- **Rules for a migration:**
  - Make it idempotent.
  - Use `TITAN_ROOT` for the checkout.
  - Never delete user data without keeping a copy.
  - Print one line per change.
  - Don't require root. If root is truly needed, print the exact command and
    exit non-zero, so the user can run it and retry.
- **Fresh installs:** `scripts/bootstrap` on a machine with no
  `~/.local/state/titan` runs `titan migrate --mark-all`. A fresh install
  already has the current layout. On an existing install, bootstrap runs
  pending migrations instead.
- **Status:** `titan migrate --status` lists every migration as done or
  pending.

## Updating

`titan update` (run by the user in a terminal; it asks for sudo) does the
following, in order:

1. Takes a lock; refuses to start while pacman is busy, with less than 2 GiB
   free on `/`, or with local changes in the checkout.
2. Takes a Snapper snapshot of `/` when a `root` config exists
   (`scripts/install-snapshots`). Otherwise it says so and continues.
3. Fast-forwards the checkout (`git pull --ff-only`) when it tracks a remote.
4. Runs `sudo pacman -Syu`. This is always a full upgrade: Arch does not
   support partial upgrades. `--no-system` skips this step.
5. Runs `titan migrate`, then `scripts/doctor`. It restarts the shell when
   shell files changed, and reports when the running kernel was replaced, so a
   reboot is due.

Agents must not run `titan update` themselves (sudo, network, system
changes); they suggest it to the user.

## Roadmap

### Phase 1: foundation

| Step | State |
| --- | --- |
| User layer separated from defaults | Done (0.2.0) |
| Version, migrations, `titan` command | Done (0.2.0) |
| `titan update` | Done; first real run by the user on 2026-10-03 (hyprland and libutf8proc upgraded, no kernel change) |
| Snapshots before updates (Snapper on Btrfs) | Enabled on this machine 2026-10-03 (`scripts/install-snapshots`; see docs/snapshots.md) |
| Packaging Titan (`titan` package, defaults in `/usr/share/titan`, own repo) | Done: `scripts/vm-test --full` passed 14/14 on a clean Arch VM. Hosting, signing and license are open owner decisions |
| First-run setup | `titan setup` plus the shell's Welcome screen; tested in a throwaway home |

### Packaging (0.2.0)

| Piece | What it does |
| --- | --- |
| `TITAN_ROOT` | Resolved once by `hyprland.lua` (environment variable, then `/usr/share/titan`, then `~/dotfiles`) and exported to every child. The shell uses `Paths`, scripts use their own location, and `hyprland.lua` loads siblings from `TITAN_ROOT`, not `~/.config/hypr` |
| `packaging/titan/PKGBUILD` | `arch=any`. Installs `/usr/share/titan/{config,scripts,lib,assets,migrations,default,version}`; `/usr/bin/{titan,titan-shell,titan-session}` (symlinks); `/etc/xdg/quickshell/umbra` (Quickshell searches XDG config dirs); `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf`; `/usr/share/wayland-sessions/titan.desktop`; docs in `/usr/share/doc/titan`. User state never ships |
| `packaging/titan-desktop/PKGBUILD` | Meta-package: `titan` plus every package in `packages/*.txt`, all in official repositories |
| `scripts/titan-session` | The "Titan" login session. On a user's first login it runs `titan setup`, then `start-hyprland -- --config $TITAN_ROOT/config/hypr/hyprland.lua`. No `~/.config/hypr` is needed |
| `titan setup` | Per user, idempotent, never overwrites. Creates the user layer; copies `mimeapps.list` and GTK settings once; writes a thin `~/.config/kitty/kitty.conf` in package mode; marks migrations on fresh installs (applies them otherwise); generates the theme; sets GTK dark preferences; enables PipeWire user units; records `setup-version` |
| Welcome screen | The shell opens it on startup while `~/.local/state/titan/welcome-done` is missing. It lists theme, wallpapers, Wi-Fi, keys and Settings; "Get started" writes the marker. Reopen with `titan-shell ipc welcome`. Migration `1791060868-first-run-markers` marks existing installs |
| `scripts/build-repo [--channel stable\|edge] [--sign KEY] [OUT]` | Builds both packages and runs `repo-add` into `~/.cache/titan/repo/CHANNEL`. Stable requires a clean checkout. Unsigned repositories are for testing only |
| `scripts/vm-test [--full] [--keep] [--memory MB]` | Boots Arch's official cloud image under QEMU/KVM on a throwaway overlay (kept on disk in `~/.cache/titan/vm/runs`), injects a key through cloud-init, installs the built packages through a detached job and runs 14 checks. Needs `qemu-base`; refuses to start without enough free memory (2 GB VM plus 1 GB) |
| `titan update` in package mode | No Git: pacman's full upgrade updates `titan` from the configured repo. The shell restarts when the version changes |

Developer mode (this laptop) keeps the `~/.config → ~/dotfiles` symlinks
through `scripts/bootstrap`, which then runs `titan setup`. Both modes share
the same setup code.

Still open before others can install Titan:

- Choose a license. The PKGBUILDs say `LicenseRef-unlicensed` until a LICENSE
  file exists.
- Create a packager GPG key for signing (`build-repo --sign`).
- Decide where the repository is hosted (for example GitHub Pages or a VPS),
  and document the `pacman.conf` entry plus key import.
- A graphical VM login to the Titan session (Phase 2 installer work).

### Phase 2 onwards

| Phase | Work |
| --- | --- |
| 2 | Installer and ISO (VM-tested); hardware profiles (GPU, laptops); themed greetd/ReGreet login; Plymouth boot splash |
| 3 | Power defaults for other machines; theming of GTK and common apps plus Git-installable themes; app install/remove menus; security setup |
| 4 | User manual; shell plugin API; branding |
