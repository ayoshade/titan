# Umbra

An original Quickshell-first desktop for shade's Intel laptop. Graphite surfaces,
quiet typography, a centered dynamic island, and restrained motion. No prebuilt
rice, no Waybar, no separate launcher or notification daemon.

Reference research and visual decisions are documented in
[design-reference.md](docs/design-reference.md).

## Reproduce

On an Arch installation with NetworkManager, Bluetooth, PipeWire/WirePlumber,
power-profiles-daemon and UFW already configured:

```sh
~/dotfiles/scripts/install-packages
~/dotfiles/scripts/bootstrap
~/dotfiles/scripts/doctor
~/dotfiles/scripts/install-login
```

Keep the checkout at `~/dotfiles`. Package installation uses a full
`pacman -Syu --needed` transaction.
Review that transaction locally. Bootstrap links configuration and refuses to
replace existing files. It also sets the GTK dark preference and Inter font.
Nothing in these scripts partitions disks, changes mount layout, edits the
bootloader, disables networking, or changes firewall rules.

After `scripts/install-login`, reboot to the dark ReGreet login screen. Choose
`shade` and the **Hyprland** session (without UWSM), then enter your password.
The desktop and Quickshell start automatically after authentication. ReGreet
remembers your user and session after the first successful login. There is no
automatic login.

If the login manager has not been installed, log into a TTY and run
`start-hyprland`. Ctrl+Alt+F3 provides a recovery console; desktop VT numbers
depend on how the session was started. The login installer enables greetd for
the next boot and preserves the currently running desktop.

## Keys

Titan uses Omarchy's complete shortcut combinations, with native Titan helpers
and Quickshell menus. Super is the Windows key. Press **Super+K** to search them.

| Key | Action |
| --- | --- |
| Super+Return | Terminal |
| Super+Space / Super+Alt+Space | Titan menu / application launcher |
| Super+Shift+F / Super+Shift+B / Super+Shift+N | Files / browser / editor |
| Super+A / C / V / X | Select all / copy / paste / cut |
| Super+Ctrl+V | Clipboard history |
| Super+Ctrl+A | Control center |
| Super+Ctrl+Shift+Space | Theme switcher |
| Super+Shift+Alt+comma | Notification history |
| Super+Escape | Session menu |
| Super+Ctrl+L | Lock |
| Super+L | Workspace layout |
| Super+W / Super+Q | Close focused window |
| Alt+Tab / Alt+Shift+Tab | Next / previous window |
| Super+1…0 / Super+Shift+1…0 | Switch workspace / move window |
| Super+F / Super+T | Fullscreen / floating |
| Print / Super+Print / Alt+Print | Screenshot / color picker / recording |

Full mappings, optional apps and policy exceptions:
[docs/keybindings.md](docs/keybindings.md). Desktop helpers and agent interfaces:
[docs/workflow.md](docs/workflow.md). Always-awake settings remain authoritative;
close-all requires confirmation. Optional Omarchy applications need separate
installation. Clipboard history is event driven, bounded to 100 items and stored
in runtime storage that clears at reboot; marked-sensitive entries are skipped.

Launcher: type to filter, arrows to select, Enter to launch. Escape or clicking
outside closes a panel. Click the island to expand its dashboard (focused
window, workspaces, clock, week, media, status, Night light and Game mode); click
the dashboard clock to morph the island into a month calendar (←/→, wheel or
arrow keys change month). The island's battery and signal icons open the
control center below the island. It has Wi-Fi, Focus, Lock, Bluetooth, Game
Mode and Night light tiles, plus Sound and Display sliders whose › opens a
detail page; hold the Wi-Fi or Bluetooth tile to toggle the radio. Titan
Settings (`qs -c umbra ipc call shell settings appearance`) is a floating
window with ten sections; every setting there can also be changed with
`scripts/workflow settings set KEY VALUE`. Screenshots are saved under
~/Pictures/Screenshots and copied to the Wayland clipboard.

## Shell architecture

```text
dotfiles/
├── config/
│   ├── hypr/                  Lua compositor modules, Hypridle, Hyprlock
│   ├── quickshell/umbra/
│   │   ├── shell.qml          Root, screen lifecycle, typed IPC
│   │   ├── theme/             Central tokens + saved appearance preferences
│   │   ├── components/        Text, icons, buttons, tiles, slider rows
│   │   ├── services/          State, audio, network, media, notices, backlight
│   │   ├── assets/icons/      Original vector UI icons
│   │   └── modules/           Background, island, tray, overlays, launcher,
│   │                          controls, connections, calendar, appearance,
│   │                          media, notifications, session menu
│   ├── kitty/                 Terminal palette and typography
│   ├── gtk-{3,4}.0/            GTK dark defaults
│   ├── xdg-desktop-portal/     Hyprland capture + GTK file chooser
│   └── mimeapps.list          Browser and file manager associations
├── assets/wallpapers/          Original Blacksite vector landscape
├── system/greetd/              Reviewed system login configuration
├── packages/                   Desktop and login package manifests
├── scripts/                    Install, link, verify, session, lock, capture
└── docs/                       Hardware, validation, operating notes
```

Logic lives in service singletons, presentation in modules. QML bindings consume
native Quickshell Hyprland IPC, NetworkManager, BlueZ, PipeWire, UPower, MPRIS,
notification-server and status-notifier APIs. PipeWire nodes use
`PwObjectTracker`. No shell command interpolates an SSID or Wi-Fi password.
Wi-Fi PSKs go through the native D-Bus API and are cleared from the field after
submission. Bluetooth power and paired-device connection are native controls.
New Bluetooth pairing opens `bluetoothctl` in Kitty for interactive PIN/agent
confirmation. Run `agent on`, `default-agent`, `scan on`, then `pair ADDRESS`,
`trust ADDRESS`, and `connect ADDRESS` as appropriate. Advanced and enterprise
network configuration opens `nmtui`.

Network scanning runs only with controls or connections open. Bluetooth scanning
stops when the connections panel closes. The clock updates once per minute. Backlight
sysfs does not deliver reliable inotify events: it refreshes after hardware-key
IPC and slider writes, plus every two seconds only while controls are open.
No hidden panel polls. Media position is not continuously sampled.

The island exists per monitor; overlays open on the focused monitor. Notifications
appear on the first monitor. Workspace marks start with 1–5 and expand through
10 as those workspaces exist. Notifications are capped at 50 live tracked items;
DND suppresses popups while retaining history. History survives QML reloads but
is not stored on disk. Closing an application's notification removes it from
live history. Media controls follow the playing player, falling back to the
first registered player. Cover images use the MPRIS artwork URL supplied by
the player; this may load an image from its remote URL. No media position timer
runs in the background. The tray is available inside the control center.

QML file changes reload automatically. After changing a `qmldir` or imports,
restart the shell:

```sh
~/dotfiles/scripts/shell-restart
```

Tune colors, spacing, radii, font defaults and durations in `theme/Theme.qml`.
Super+Ctrl+Shift+Space opens a searchable horizontal theme carousel inspired by the referenced
saneAspect video. Left/Right selects a card; Enter applies it, Escape closes it.
Click selects; double-click applies. Nine dark palettes update the shell, Kitty
and compositor borders together. Theme changes persist across login. GTK apps
retain their dark base. Palette data lives in `theme/palettes.json`; generated
`kitty/theme.conf` and `hypr/theme.lua` are reproducible with
`scripts/apply-theme THEME_ID`.

The palette and accent stay in `theme/preferences.json`. All other shell
settings are declared in `theme/settings-schema.json`, with user values in
`~/.local/state/titan/settings.json` (outside Git). Wallpapers belong to themes:
`~/Pictures/Wallpapers/<theme>/` holds each theme's set, and applying a theme
switches to its wallpaper. The wallpaper picker (Settings → Appearance →
Wallpaper, or `ipc call shell wallpapers`) chooses within the set, and changes
crossfade. `scripts/fetch-wallpapers [--count N] [THEME…]` downloads
colour-matched sets from Wallhaven's Toplist. These images are their authors'
work, so keep them out of Git. The bundled Blacksite landscape stays
selectable under every theme. Wallpapers are decoded at screen size and never
repainted on a timer.
The island expands briefly for volume/brightness changes; a click opens the
dashboard, which collapses when the pointer leaves or Escape is pressed. Its fixed reserved space keeps
windows from jumping during expansion.
Hyprland appearance lives independently in `hypr/appearance.lua`. Monitor scale
is 1 for this machine's 1366×768 display. Keyboard layout is US. The launcher
only executes installed desktop entries; it is not a shell-command runner.

## Session behavior

Hyprland launches Quickshell and the small polkit authentication agent.
GTK portals handle file dialogs; the Hyprland portal handles screen sharing and
screenshots. PipeWire socket activation and WirePlumber provide audio.
Hyprlock uses immediate rendering with lock-screen animations disabled to avoid
the black-screen failure observed during TTY switching.
This laptop uses an always-awake policy: Hypridle is not started, automatic
locking and display-off timers are absent, and manual locking remains available.
`scripts/install-always-awake` installs the reviewed system policy with local sudo:
lid closure, idle and sleep keys are ignored; all sleep/hibernate targets are
masked. A boot service disables battery-aware profile switching and selects
Performance. logind reloads without restarting the desktop. Suspend is absent
from the session menu. Explicit reboot, power off and logout retain confirmation.

This is a policy for the development laptop, not a requirement for every Titan
machine. Keep it on external power for unattended operation. Hardware loss of
power, critical thermal protection, and a firmware hard-power-off cannot be
prevented by desktop settings. See [always-awake.md](docs/always-awake.md) for
installation, validation and restoration. Manual lock rendering remains a
hands-on check in `docs/verification.md`.

## Recovery

If the shell fails, Super+Return still opens Kitty. Run `scripts/shell-restart`.
From a TTY it discovers the running Hyprland display. Inspect logs with:

```sh
qs -c umbra log
hyprctl configerrors
journalctl --user -b -u xdg-desktop-portal -u xdg-desktop-portal-hyprland
```

From a TTY use `qs -c umbra log --help` for instance selection if needed. User
configuration is tracked in Git; restore a known commit and restart the shell.
Bootstrap never overwrites a foreign config: move it aside manually only after
reviewing and backing it up. This repository does not manage passwords, browser
profiles, Wi-Fi credentials or machine-wide networking configuration.

API references: [Quickshell 0.3.1](https://quickshell.org/docs/v0.3.1/types/),
[Hyprland Lua configuration](https://wiki.hypr.land/configuring/core/).

## Graphical login administration

The optional login stack is greetd, ReGreet and Cage. Cage runs only the
greeter, supports VT switching, and exits when the authenticated desktop starts.
ReGreet uses the system Hyprland session entry, which executes `start-hyprland`.
Quickshell remains the desktop shell.

`scripts/install-login` requires sudo, validates the TOML and installed CLI,
backs up existing `/etc/greetd` configuration into `umbra-backup.*`, installs
root-owned copies, verifies the systemd unit, and enables greetd for the next
boot. It does not start or restart greetd in the current session. Config changes
under `system/greetd/` must be reinstalled with that script to take effect.

If graphical login fails, use Ctrl+Alt+F3, log in, then inspect:

```sh
systemctl status greetd --no-pager
journalctl -b -u greetd --no-pager
```

To return to text login on the next boot:

```sh
sudo systemctl disable greetd.service
```

The original enabled getty on tty1 is preserved. Do not stop greetd while you
have an active desktop launched by it; disabling alone changes future boots.
Login references: [ReGreet](https://github.com/rharish101/ReGreet),
[greetd configuration](https://man.archlinux.org/man/greetd.5.en).
