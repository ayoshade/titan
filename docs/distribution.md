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
| `titan update` | Done; first real use pending |
| Snapshots before updates (Snapper on Btrfs) | `scripts/install-snapshots` written and dry-run tested; the user runs it with sudo (docs/snapshots.md) |
| Packaging Titan (`titan` package, defaults in `/usr/share/titan`, own repo) | Planned, below |
| First-run setup (user, owner, theme, network) | Planned |

### Packaging plan

Today the shell, Hyprland and Kitty load their configs through
`~/.config/{quickshell,hypr,kitty} → ~/dotfiles/config/...` symlinks, and
scripts assume `~/dotfiles`.

1. Replace the remaining hard-coded `~/dotfiles` paths with a single
   `TITAN_ROOT`, discovered from the script location or `/usr/share/titan`.
2. Ship Titan as an Arch package:
   - `titan` contains defaults, scripts, shell, assets, migrations and
     `version`.
   - `titan-desktop` is a meta-package depending on `packages/*.txt`.
   - `/usr/bin/titan` and `/usr/bin/titan-shell` are installed.
3. Keep `~/.config/{hypr,kitty,quickshell}` as thin user files that load the
   packaged defaults first, then `~/.config/titan` overrides. Installing over
   an existing setup goes through a migration.
4. Run a pacman repository for `titan` with stable and edge channels, and
   point `titan update` at it. The developer checkout keeps working through a
   developer mode.
5. Build and test in a VM; never on the daily laptop.

### Phase 2 onwards

| Phase | Work |
| --- | --- |
| 2 | Installer and ISO (VM-tested); hardware profiles (GPU, laptops); themed greetd/ReGreet login; Plymouth boot splash |
| 3 | Power defaults for other machines; theming of GTK and common apps plus Git-installable themes; app install/remove menus; security setup |
| 4 | User manual; shell plugin API; branding |
