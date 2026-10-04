# Titan

Titan is an Arch-based, agent-friendly Linux desktop by **Cristian Adrian
Paredez** (`ayoshade`): Hyprland plus its own Quickshell shell. The shell is a
centered dynamic island, a control center, a launcher and a Settings app, in a
dark black-and-graphite style modelled on saneAspect's designs. Everything is
original code: no Waybar, no prebuilt rice, no separate launcher or
notification daemon. The shell's internal name is **umbra**.

Released: **Titan 0.2.0**, published as signed Arch packages. The **0.3.0
development tree** adds an experimental QEMU-only UEFI installer and live ISO,
hardware profiles and a boot splash (see [docs/installation.md](docs/installation.md)).
Interrupted installer attempts can be inspected and recovered in the same live
VM session before a separately confirmed fresh installation.
Version 0.3.0 has not been published. Licensed under
[Apache-2.0](LICENSE); attributions are in [NOTICE](NOTICE).

## Features

- **Island:** workspaces, clock, signal and battery at the top center.
  - Click it for a dashboard: focused window, workspace list, week, media,
    status, Night light and Game mode.
  - Click the dashboard clock and it becomes a month calendar.
  - Volume and brightness changes expand it briefly.
  - Optional notch mode attaches it to the top edge; Game mode turns it into a
    full-width bar.
- **Control center** (click the battery or signal icons):
  - tiles for Wi-Fi, Focus, Lock/power, Bluetooth, Game Mode and Night light;
  - Sound and Display sliders with detail pages (networks, devices,
    outputs/inputs/apps, monitors, night-light temperature);
  - media, running tray apps and notifications.
- **Settings window:** ten sections (Bar & Island, Media, Clock & Date,
  Appearance, Motion, Launcher, Notifications, Control Center, Lock Screen,
  System) with search. Every setting can also be set from the command line.
- **Launcher and menus:**
  - Super+Alt+Space opens apps; Super+Space opens Titan's menus (capture,
    toggles, hardware, themes, wallpapers, agents, settings, system).
  - Super+K searches all keybindings; Super+Escape opens the session menu.
- **Themes and wallpapers:** nine dark palettes recolour the shell, Kitty and
  window borders together. Each theme has its own wallpapers, chosen in a
  carousel with a crossfade.
- **Capture:** region, window and monitor screenshots, OCR, colour picker and
  screen recording.
- **Notifications** (grouped by app), clipboard history, emoji picker,
  calculator, reminders and world clock.
- **Updates:** `titan update` takes a Snapper snapshot, runs a full Arch
  upgrade and applies migrations; your own settings are never overwritten.
- **Agent support:** documented commands and skills for Claude Code and Codex
  (see [AGENTS.md](AGENTS.md), `agents/skills/` for development and
  `default/agents/skills/` for end users).

Keyboard chords follow Omarchy's complete set (231 bindings), implemented
independently. See [docs/keybindings.md](docs/keybindings.md).

## Install

### From the Titan package repository

On an existing Arch installation with NetworkManager, PipeWire and a user
account:

```sh
curl -fsSLO https://raw.githubusercontent.com/ayoshade/titan/main/keys/titan-packager.asc
sudo pacman-key --add titan-packager.asc
sudo pacman-key --lsign-key 8A648F6B462B95C6
printf '\n[titan]\nServer = https://github.com/ayoshade/titan/releases/download/repo-stable\n' | sudo tee -a /etc/pacman.conf
sudo pacman -Syu titan-desktop
```

Packages are signed with key `8A648F6B462B95C6` (fingerprint
`2AD3 24F1 003E A830 989F 5129 8A64 8F6B 462B 95C6`). Choose the **Titan**
session at your login screen. On first login Titan sets up your account
(`titan setup`) and shows a short Welcome screen. Optionally install the
reviewed greetd login screen with `/usr/share/titan/scripts/install-login`.

### From a Git checkout (development)

```sh
git clone https://github.com/ayoshade/titan.git ~/dotfiles
~/dotfiles/scripts/install-packages     # full pacman -Syu of packages/*.txt; review the transaction
~/dotfiles/scripts/bootstrap            # links ~/.config/{hypr,kitty,quickshell,gtk-*} and runs `titan setup`
~/dotfiles/scripts/doctor               # health check
~/dotfiles/scripts/install-login        # optional: greetd + ReGreet (sudo)
```

`bootstrap` refuses to replace existing files. None of these scripts
partitions disks, changes mount layout, edits the bootloader, disables
networking or changes firewall rules.

## Everyday use

The [modular workflow additions](docs/operations.md) provide developer
dotfiles, package/runtime/service recipes, default-app choices, web apps,
configuration recovery, hooks and optional QML extensions. Install, Setup
and Remove are available in Super+Space. [Omarchy coverage](docs/research/omarchy.md)
tracks remaining work against the pinned reference; full parity is ongoing.

| Key | Action |
| --- | --- |
| Super+Return | Terminal (Kitty) |
| Super+Space / Super+Alt+Space | Titan menu / application launcher |
| Super+K | Search every shortcut |
| Super+Shift+F / Super+Shift+B / Super+Shift+N | Files / browser / editor |
| Super+A / C / V / X | Select all / copy / paste / cut |
| Super+Ctrl+V | Clipboard history |
| Super+Ctrl+A | Control center |
| Super+Ctrl+Shift+Space | Theme carousel |
| Super+Shift+Alt+comma | Notification history |
| Super+Escape | Session menu |
| Super+Ctrl+L | Lock |
| Super+L | Toggle workspace layout (dwindle/scrolling) |
| Super+W / Super+Q | Close window |
| Super+1…0 / Super+Shift+1…0 | Switch workspace / move window |
| Super+F / Super+T | Fullscreen / floating |
| Print / Super+Print / Alt+Print | Screenshot / colour picker / recording |
| Super+Ctrl+N | Night light |

Search menus filter as you type; ↑/↓ or Tab select and Enter runs. Escape or
clicking outside closes a panel. Hold the Wi-Fi or Bluetooth tile to switch the
radio. Screenshots go to `~/Pictures/Screenshots` and the clipboard;
recordings go to `~/Videos/Recordings`.

## Make it yours

Titan keeps three layers apart, so updates never overwrite your choices:

| Layer | Where | Contents |
| --- | --- | --- |
| Defaults | `/usr/share/titan` (package) or the checkout | Shipped configuration, shell, scripts, migrations |
| Your configuration | `~/.config/titan/` | `preferences.json` (theme, accent), `settings.json` (Settings window), `hypr.lua` and `kitty.conf` (your overrides, loaded last) |
| Machine state | `~/.local/state/titan/` | Generated theme files, runtime toggles, migration markers |

`~/.config/mimeapps.list`, the GTK settings and (packaged installs)
`~/.config/kitty/kitty.conf` are copied once and then belong to you.

**Developer tools come from [mise](https://mise.jdx.dev).** Titan installs it,
activates it for interactive Bash (setup appends one line to `~/.bashrc`
that sources `default/bash/rc`) and puts its shims on the Hyprland session
`PATH`, so tools also work from the launcher and keybindings. Use it for CLIs
and language runtimes that are not part of the desktop:

```sh
mise use -g gh node@lts python@3.13   # global tools, in ~/.config/mise/config.toml
mise use go@1.23                      # per project, in ./mise.toml
mise upgrade                          # update installed tools
```

```sh
titan version                       # version and install location
titan theme list | current | nord   # themes
titan settings get | set KEY VALUE | reset KEY | schema
titan wallpaper list | next | set PATH
titan shell status | restart | ipc METHOD | open PANEL
titan doctor                        # health check
titan update check --json           # read-only local update readiness
titan update status --json          # last update stage/result and current lock
titan boot status --json             # experimental installer bootloader status
titan snapshot list --json           # experimental Limine recovery preview inventory
titan hardware --json                # read-only hardware inventory and installer packages
titan skills [--dry-run]             # link the three end-user skills for Codex and Claude
titan update                        # snapshot, full upgrade, migrations (asks for sudo)
```

- **Settings window:** `titan shell open settings appearance` (or another
  section name).
- **Wallpapers:** they live in `~/Pictures/Wallpapers/<theme>/`.
  `scripts/fetch-wallpapers [--count N] [THEME…]` downloads colour-matched sets
  from Wallhaven. They are their authors' work, so never commit them. The
  bundled Blacksite landscape is selectable under every theme.
- **Agents:** the `titan` skill covers customization, `titan-app` building
  themed Qt Quick apps, and `diagnose-crash` reading core dumps. Seven development
  guides under `agents/skills/` adapt Omarchy's development guidance for Titan.
  Setup/update link only the three end-user skills under `default/agents/skills/`
  for Codex and Claude; `titan skills --dry-run` previews missing links without
  replacing personal skills. See [docs/agent-skills.md](docs/agent-skills.md).

## Updating and recovery

- **Updating:** `titan update` refuses to start if pacman is busy, disk space
  is low or the checkout has local changes. It then takes a snapshot, updates
  Titan (Git or package), runs `pacman -Syu`, applies migrations, runs the
  health check, restarts the shell when needed and tells you when a reboot is
  due.
  `titan update check` checks readiness without starting an update;
  `titan update status` explains the last stage/result, including interruption.
- **Snapshots:** `scripts/install-snapshots` enables Snapper and snap-pac on a
  Btrfs root, so every pacman transaction is snapshotted. Inspecting, undoing,
  rolling back and removing are covered in
  [docs/snapshots.md](docs/snapshots.md).
  Experimental Limine QEMU installs also support confirmed offline snapshot
  restore from the Titan live ISO, retaining the displaced root and boot files.
- **If the shell misbehaves:** Super+Return still opens Kitty. Run
  `titan-shell restart` (or `scripts/shell-restart` from a TTY). It escalates
  to TERM/KILL if Quickshell hangs while exiting.
- **If you can't unlock:** after 3 wrong passwords the account is locked for
  10 minutes, and the lock screen says so. After a lockout, enter the password
  a second time if the first try is refused. For a black or crashed lock, use
  [docs/lock-recovery.md](docs/lock-recovery.md) from a TTY (Ctrl+Alt+F3).
- **Logs:**

  ```sh
  qs -c umbra log
  hyprctl configerrors
  journalctl --user -b -u xdg-desktop-portal -u xdg-desktop-portal-hyprland
  ```

- **Reverting your own changes:** use `titan settings reset KEY`, or apply your
  previous theme with `titan theme ID`. Titan does not manage passwords,
  browser profiles, Wi-Fi credentials or machine-wide networking.

## Building and releasing

`packaging/titan` and `packaging/titan-desktop` hold the PKGBUILDs.

```sh
tools/build-repo --channel edge                         # local pacman repository
tools/vm-test --full                                    # install local builds on a throwaway Arch VM (needs qemu-base)
tools/vm-test --full --from-repo                        # install from the published repository, as a user would
tools/vm-test --graphical                               # real greeter authentication and first-login shell checks
tools/vm-test --workflows                               # graphical + runtimes, services, databases and optional apps
tools/publish-repo --channel stable --sign KEYID --yes  # GitHub release repo-stable
```

Release, signing and user setup are documented in
[docs/distribution.md](docs/distribution.md).
The experimental ISO builder and installation tests run inside QEMU; see
[docs/installation.md](docs/installation.md) for the complete sequence.

## Layout

```text
├── config/
│   ├── hypr/                Hyprland Lua: appearance, input, rules, bindings/, Hyprlock, Hypridle
│   ├── quickshell/umbra/    The shell
│   │   ├── shell.qml        Root, per-screen windows, typed IPC
│   │   ├── theme/           Theme, Settings and Paths singletons; palettes; settings schema; defaults
│   │   ├── services/        Audio, network, media, notices, backlight, toggles, wallpapers, UI state
│   │   ├── components/      Shared controls (Tile, Switch, PillSlider, SearchMenu, …)
│   │   ├── modules/         Island, dashboard, calendar, control center, Settings, menus, panels
│   │   └── assets/          Icons, menu definitions, emoji data
│   ├── kitty/  gtk-3.0/  gtk-4.0/  xdg-desktop-portal/
├── agents/skills/           Development guides for repository agents
├── default/                 Defaults copied once, Bash defaults (mise) and the three end-user agent skills
├── lib/titan/               Python behind bin/workflow (desktop operations, paths)
├── bin/                     Public commands: titan, titan-shell, titan-session, titan-install, workflow
├── scripts/                 Internal helpers: bootstrap, install-*, apply-theme, fetch-wallpapers,
│                            doctor, lock, screenshot (plus compatibility links to bin/ for one release)
├── tools/                   Developer and release tooling, not packaged: build-repo, publish-repo,
│                            build-iso, vm-test, vm-build-iso, vm-install-test, vm-graphical
├── migrations/              Numbered upgrade steps run by `titan migrate`
├── packaging/               PKGBUILDs for titan and titan-desktop
├── packages/                Package manifests (desktop, workflow, login)
├── system/                  Reviewed templates for privileged config (greetd, power)
├── keys/                    Public packager key
├── assets/wallpapers/       Original Blacksite landscape
├── docs/                    Design research, distribution, verification, hardware, recovery
├── version  LICENSE  NOTICE
```

The shell keeps logic in service singletons and presentation in modules. It
uses native Quickshell APIs for Hyprland, NetworkManager, BlueZ, PipeWire,
UPower, MPRIS, notifications and the system tray. Theme tokens come from one
palette catalog and the settings schema.

## Privacy and resource notes

- **Credentials:** Wi-Fi passwords go through NetworkManager's D-Bus API. No
  command line contains an SSID or password. New Bluetooth pairing opens
  `bluetoothctl` for PIN confirmation; advanced networking opens `nmtui`.
- **Clipboard:** history is event driven, capped at 100 items and kept in
  runtime storage that clears at reboot. Entries marked sensitive are skipped.
- **No background polling:**
  - Network and Bluetooth scans run only while their panels are open.
  - Backlight is re-read after key presses and slider changes, and every two
    seconds only while the control center is open.
  - Media position updates once a second only while a media view is open and
    playing.
- **Cover art** uses the player's artwork URL, which may load a remote image.
- **Notifications:** at most 50 are tracked; Do Not Disturb hides pop-ups but
  keeps history; history is not written to disk.

## This development laptop

The reference machine is an Intel laptop (1366×768, Arch, systemd-boot, Btrfs,
UFW) running from the checkout. Two of its policies are laptop-specific, not
Titan defaults:

- **Always awake** (`scripts/install-always-awake`, sudo): Hypridle is not
  started. Lid, idle and sleep keys are ignored, and sleep and hibernate are
  masked. Performance profile at boot. Suspend is absent from the session and
  power menus; reboot, power off and log out still confirm. Keep it on external
  power. Details and restoration: [docs/always-awake.md](docs/always-awake.md).
- **Hyprlock** uses immediate rendering without animations, to avoid a
  black-screen failure seen during TTY switching. Manual lock rendering is
  still a hands-on check ([docs/verification.md](docs/verification.md)).

Hardware notes: [docs/hardware.md](docs/hardware.md).

## Graphical login (greetd)

The optional login stack is greetd, ReGreet and Cage. Cage runs only the
greeter and exits when the desktop starts. Sessions come from
`/usr/share/wayland-sessions`: **Titan** (`titan-session`) for packaged
installs, or **Hyprland** (`start-hyprland`) for the checkout.

`scripts/install-login` needs sudo and:
- validates the TOML and the installed CLI;
- backs up `/etc/greetd` into `umbra-backup.*` and installs root-owned copies;
- verifies the unit and enables greetd for the next boot, without restarting
  the running one.

Changes under `system/greetd/` take effect only after reinstalling. If login
fails, press Ctrl+Alt+F3, log in and run:

```sh
systemctl status greetd --no-pager
journalctl -b -u greetd --no-pager
sudo systemctl disable greetd.service   # return to text login next boot
```

## Documentation

| Document | Contents |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Rules and context for AI agents (Claude Code, Codex) |
| [docs/distribution.md](docs/distribution.md) | Layers, migrations, updates, packaging, releasing, roadmap |
| [docs/installation.md](docs/installation.md) | Experimental UEFI ISO, installer, hardware profiles and QEMU testing |
| [docs/agent-skills.md](docs/agent-skills.md) | Bundled agent skills, Omarchy port mappings, installation and removal |
| [docs/workflow.md](docs/workflow.md) | Command and IPC interfaces |
| [docs/keybindings.md](docs/keybindings.md) | Complete shortcut reference |
| [docs/snapshots.md](docs/snapshots.md) | Snapshots and recovery |
| [docs/lock-recovery.md](docs/lock-recovery.md) | Lock screen states, lockouts and TTY recovery |
| [docs/design-reference.md](docs/design-reference.md) and [docs/research/](docs/research/) | saneAspect research, measurements, checklists |
| [docs/verification.md](docs/verification.md) | Dated record of what was tested, and what was not |
| [docs/always-awake.md](docs/always-awake.md), [docs/hardware.md](docs/hardware.md) | Development-laptop policy and hardware |

API references: [Quickshell 0.3.1](https://quickshell.org/docs/v0.3.1/types/),
[Hyprland Lua configuration](https://wiki.hypr.land/configuring/core/),
[ReGreet](https://github.com/rharish101/ReGreet),
[greetd](https://man.archlinux.org/man/greetd.5.en).

## License

Copyright 2026 Cristian Adrian Paredez and Titan contributors. Licensed under
the Apache License, Version 2.0 ([LICENSE](LICENSE)); see [NOTICE](NOTICE) for
third-party attributions.
