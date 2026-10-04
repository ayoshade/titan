# Titan as a distribution

Titan started as a personal dotfiles checkout. This document records how it
becomes a distribution other people can install and update without losing
their changes. It also records which parts exist today. Read it before changing
layout, installation or updates.

## Layers

| Layer | Location | Owner | Updates may |
| --- | --- | --- | --- |
| Defaults | The checkout (`~/dotfiles`) or package (`/usr/share/titan`) | Titan | Replace freely |
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
- Agent discovery links live in `${CODEX_HOME:-$HOME/.codex}/skills` and
  `~/.claude/skills`; the three end-user skill sources remain in Titan's defaults.
  `titan skills`
  registers missing links and refuses custom entries before writing. Setup and
  update call it too, reporting conflicts without overwriting them. See
  [agent-skills.md](agent-skills.md). The seven Omarchy development-guide ports
  live separately in `agents/skills/` and are not shipped as desktop defaults.

The first migration (`migrations/1791060086-user-layer.sh`) moved this
machine from the old layout. That layout tracked the user's theme in Git,
wrote generated files into the checkout, kept settings in state, and linked
`mimeapps.list` into the repo.

## Version and migrations

The 0.3.0 development tree also ships original developer dotfiles under
`default/config/`, optional recipes under `default/catalog/` and modular Bash
defaults. Setup installs only missing dotfiles; migration
`1791096000-developer-defaults.sh` does the same on existing installs. Optional
packages/services are explicit operations, not new meta-package dependencies.
See [operations](operations.md) for backup/restore, defaults, hooks and plugins.
Generated application palettes stay in machine state and custom configs win.

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
5. Runs `titan migrate`, registers bundled agent skills, then `scripts/doctor`.
   It restarts the shell when shell files changed, and reports when the running
   kernel was replaced, so a
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
| Packaging Titan (`titan` package, defaults in `/usr/share/titan`, own repo) | Done: `tools/vm-test --full` passed 14/14 on a clean Arch VM; Apache-2.0; hosted as GitHub releases (`tools/publish-repo`). signed with key 8A648F6B462B95C6 |
| First-run setup | `titan setup` plus the shell's Welcome screen; tested in a throwaway home |

### Packaging (0.2.0)

| Piece | What it does |
| --- | --- |
| `TITAN_ROOT` | Resolved once by `hyprland.lua` (environment variable, then `/usr/share/titan`, then `~/dotfiles`) and exported to every child. The shell uses `Paths`, scripts use their own location, and `hyprland.lua` loads siblings from `TITAN_ROOT`, not `~/.config/hypr` |
| `packaging/titan/PKGBUILD` | `arch=any`. Installs `/usr/share/titan/{bin,config,scripts,lib,assets,migrations,default,packages,system,keys,version}` (release 2 added `packages`, `system` and `keys`, which `doctor`, `install-login` and `install-always-awake` read); `/usr/bin/{titan,titan-shell,titan-session}` (symlinks into `bin/`; 0.3.0 moved them from `scripts/`, which keeps compatibility links); developer tooling in `tools/` is not packaged; `/etc/xdg/quickshell/umbra` (Quickshell searches XDG config dirs); `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf`; `/usr/share/wayland-sessions/titan.desktop`; docs in `/usr/share/doc/titan`. User state never ships |
| `packaging/titan-desktop/PKGBUILD` | Meta-package: `titan` plus every package in `packages/*.txt`, all in official repositories |
| `bin/titan-session` | The "Titan" login session. On a user's first login it runs `titan setup`, then `start-hyprland -- --config $TITAN_ROOT/config/hypr/hyprland.lua`. No `~/.config/hypr` is needed |
| `titan setup` | Per user, idempotent, never overwrites. Creates the user layer; copies `mimeapps.list` and GTK settings once; writes a thin `~/.config/kitty/kitty.conf` in package mode; marks migrations on fresh installs (applies them otherwise); generates the theme; sets GTK dark preferences; enables PipeWire user units; appends one marked line to `~/.bashrc` that sources `default/bash/rc` (mise activation; `scripts/install-bash-defaults`, also migration `1791072383-bash-defaults-mise`); records `setup-version` |
| mise | Titan's default tool and runtime manager (`packages/workflow.txt`). Interactive Bash activates it through `default/bash/rc`; `hyprland.lua` prepends `$MISE_DATA_DIR/shims` (default `~/.local/share/mise/shims`) to the session `PATH` once. Titan ships no global tool list: `~/.config/mise/config.toml` belongs to the user |
| Welcome screen | The shell opens it on startup while `~/.local/state/titan/welcome-done` is missing. It lists theme, wallpapers, Wi-Fi, keys and Settings; "Get started" writes the marker. Reopen with `titan-shell ipc welcome`. Migration `1791060868-first-run-markers` marks existing installs |
| `tools/build-repo [--channel stable\|edge] [--sign KEY] [OUT]` | Builds both packages and runs `repo-add` into `~/.cache/titan/repo/CHANNEL`. Stable requires a clean checkout. Unsigned repositories are for testing only |
| `tools/vm-test [--full] [--keep] [--memory MB] [--from-repo [stable\|edge]]` | Boots Arch's official cloud image under QEMU/KVM on a throwaway overlay (kept on disk in `~/.cache/titan/vm/runs`), injects a key through cloud-init, installs the built packages (or, with `--from-repo`, the published repository using the documented user steps) through a detached job and runs its install, setup, layout and config checks. Needs `qemu-base`; refuses to start without enough free memory (2 GB VM plus 1 GB) |
| `titan update` in package mode | No Git: pacman's full upgrade updates `titan` from the configured repo. The shell restarts when the version changes |

`tools/vm-test --workflows` extends graphical/full installation with real mise
runtimes, framework provisioning, Docker database persistence, optional
services and terminal windows. It tests the local checkout, keeps source hashes,
command logs, JSON results and screenshots in the run directory, and reboots
only the guest if its upgrade replaced the running kernel's modules. It doesn't
install packages or change services on the host.

Developer mode (this laptop) keeps the `~/.config → ~/dotfiles` symlinks
through `scripts/bootstrap`, which then runs `titan setup`. Both modes share
the same setup code.

## Releasing

Titan is licensed under Apache-2.0 (`LICENSE`; attributions in `NOTICE`,
installed as `/usr/share/licenses/titan/NOTICE`). Packages are hosted for free
as GitHub releases of this repository. The fixed tags `repo-stable` and
`repo-edge` act as the two channels; pacman reads release assets directly.

### 1. Packager signing key (once, by the owner)

Signing proves packages came from you. The key's passphrase is a secret:
create it yourself and never give it to an agent or put it in Git.

```sh
# Use a name and email you are happy to make public.
gpg --quick-generate-key "Titan Packages <you@example.com>" ed25519 sign 3y
gpg --list-secret-keys --keyid-format long      # the KEYID is after "ed25519/"
mkdir -p ~/dotfiles/keys
gpg --armor --export KEYID > ~/dotfiles/keys/titan-packager.asc   # public key: commit this
gpg --armor --export-secret-keys KEYID > /path/to/offline-backup.asc   # private: offline backup, never in Git
```

### 2. Publish

```sh
tools/publish-repo --channel edge                 # dry run: lists files and the pacman URL
tools/publish-repo --channel edge --yes           # publish edge (unsigned is allowed for testing)
tools/publish-repo --channel stable --sign KEYID --yes   # stable must be signed; needs a clean checkout
```

`publish-repo` builds through `build-repo`, creates the release if missing
(edge is marked pre-release) and uploads with `gh`. It deletes package files
no longer in the database, so files and database always match. Bump
`version` (and add migrations) before publishing a release users should get.

### 3. Users: add the repository

Titan's packager key: `keys/titan-packager.asc`, key ID `8A648F6B462B95C6`,
fingerprint `2AD3 24F1 003E A830 989F  5129 8A64 8F6B 462B 95C6`, expiring
2029-10-02 (extend it with `gpg --quick-set-expire` before then).


```sh
curl -fsSLO https://raw.githubusercontent.com/ayoshade/titan/main/keys/titan-packager.asc
sudo pacman-key --add titan-packager.asc && sudo pacman-key --lsign-key 8A648F6B462B95C6
```

Then append to `/etc/pacman.conf`, after the official repositories:

```ini
[titan]
Server = https://github.com/ayoshade/titan/releases/download/repo-stable
```

Install with `sudo pacman -Syu titan-desktop`. From then on, `titan update`
(a full `pacman -Syu`) keeps Titan current. For edge, use `repo-edge` and add
`SigLevel = Optional TrustAll` only on test machines while edge is unsigned.

Graphical first-login now has a QEMU test, including real authentication,
Welcome and live shell IPC. See the 0.3.0 development work below.

### Phase 2: 0.3.0 development (not published)

The experimental installer, ISO builder, hardware catalog, login branding and
Plymouth template are described in [installation.md](installation.md). Apply
is guarded to live QEMU VMs; no physical installation is supported yet. The
public stable repository remains 0.2.0, and the new installer rejects that older
version before writes. Use the explicit local VM repository for development.
Fresh QEMU installations may select Limine with `--bootloader limine`;
`systemd-boot` remains the default. The Bash refresh helper owns generated
kernel entries and a guarded EFI update hook. Snapshot boot/restore and
existing-machine migration remain open; see [installation](installation.md).

The UEFI ISO → dedicated-disk install → ISO-detached boot → ReGreet
authentication → fresh-account Welcome path passed in QEMU. Local package
regression checks passed 17/17. See [verification.md](verification.md) for
exact observations and runtime/visual limitations.

`titan-desktop` now includes the network, Bluetooth, power and audio service
packages from `packages/services.txt`. `install-login --no-packages` configures
a target whose package transaction is already complete. Login guidance names
the user's account and Titan session rather than the development laptop user.
The setup code distinguishes a session-created `setup.log` from existing user
state, preserving Welcome on a genuine first login.

Still open before release: encryption, dual boot, physical GPU/laptop profiles,
signed 0.3.0 repository/ISO testing, wider boot/login coverage and distribution
license/source review. The initial VM prototype uses UEFI, an unencrypted
Btrfs root and US/en_US.UTF-8. This milestone does not complete those broader
Phase 2 requirements.

Installer recovery now records live-session checkpoints and exposes read-only
`--status` plus confirmed `--recover --disk DEVICE`. Recovery verifies and
releases owned mounts, preserves partial disk data and permits a separately
confirmed fresh attempt. Resume across live boots remains open; see
[installation.md](installation.md).

### Phase 2 onwards

| Phase | Work |
| --- | --- |
| 2 | Installer and ISO (VM-tested); hardware profiles (GPU, laptops); themed greetd/ReGreet login; Plymouth boot splash |
| 3 | Power defaults for other machines; theming of GTK and common apps plus Git-installable themes; app install/remove menus; security setup |
| 4 | User manual; shell plugin API; branding |
