# Umbra

An original Quickshell-first desktop for shade's Intel laptop. Graphite surfaces,
quiet typography, a compact contextual pill, and restrained motion. No prebuilt
rice, no Waybar, no separate launcher or notification daemon.

## Reproduce

On an Arch installation with NetworkManager, Bluetooth, PipeWire/WirePlumber,
power-profiles-daemon and UFW already configured:

```sh
~/dotfiles/scripts/install-packages
~/dotfiles/scripts/bootstrap
~/dotfiles/scripts/doctor
start-hyprland
```

Keep the checkout at `~/dotfiles`. `~/dotfilez` is a symlink to the same Git
repository. Package installation uses a full `pacman -Syu --needed` transaction.
Review that transaction locally. Bootstrap links configuration and refuses to
replace existing files. It also sets the GTK dark preference and Inter font.
Nothing in these scripts partitions disks, changes mount layout, edits the
bootloader, disables networking, or changes firewall rules.

Launch from a logged-in TTY with `start-hyprland`. There is intentionally no
automatic login or display manager. Ctrl+Alt+F1 returns to the first console;
Ctrl+Alt+F2 returns to the desktop started from the second console.

## Keys

| Key | Action |
| --- | --- |
| Super+Return | Kitty terminal |
| Super+Space | Quickshell application launcher |
| Super+A | Control center |
| Super+N | Notification center |
| Super+Shift+E | Session menu |
| Super+E / Super+B | Thunar / Firefox |
| Super+L | Hyprlock |
| Super+Q | Close focused window |
| Super+F / Super+V | Fullscreen / floating |
| Super+1…0 | Workspace 1…10 |
| Super+Shift+1…0 | Move window to workspace |
| Super+arrows | Focus a neighboring window |
| Super+Shift+arrows | Move a window |
| Super+left/right mouse drag | Move / resize window |
| Print / Super+Print | Region / full screenshot |
| Media and brightness keys | Audio / backlight / media |
| Three-finger horizontal swipe | Change workspace |

Launcher: type to filter, arrows to select, Enter to launch. Escape or clicking
outside closes a panel. Bar sections open their related controls. Screenshots
are saved under `~/Pictures/Screenshots` and copied to the Wayland clipboard.
No clipboard history daemon retains sensitive clipboard content.

## Shell architecture

```text
dotfiles/
├── config/
│   ├── hypr/                  Lua compositor modules, Hypridle, Hyprlock
│   ├── quickshell/umbra/
│   │   ├── shell.qml          Root, screen lifecycle, typed IPC
│   │   ├── theme/             Central Theme singleton
│   │   ├── components/        Text, actions, slider rows
│   │   ├── services/          State, audio, network, media, notices, backlight
│   │   └── modules/           Background, bar, tray, overlays, launcher,
│   │                          control center, notifications, session menu
│   ├── kitty/                 Terminal palette and typography
│   ├── gtk-{3,4}.0/            GTK dark defaults
│   ├── xdg-desktop-portal/     Hyprland capture + GTK file chooser
│   └── mimeapps.list          Browser and file manager associations
├── packages/desktop.txt        Exact direct package manifest
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

Network scanning runs only with the control center open. Bluetooth scanning
stops when that panel closes. The clock updates once per minute. Backlight
sysfs does not deliver reliable inotify events: it refreshes after hardware-key
IPC and slider writes, plus every two seconds only while controls are open.
No hidden panel polls. Media position is not continuously sampled.

The bar exists per monitor; overlays open on the focused monitor. Notifications
appear on the first monitor. Workspace buttons start with 1–5 and expand through
10 as those workspaces exist. Notifications are capped at 50 live tracked items;
DND suppresses popups while retaining history. History survives QML reloads but
is not stored on disk. Closing an application's notification removes it from
live history. Media controls follow the playing player, falling back to the
first registered player. No cover images are downloaded by the shell.

QML file changes reload automatically. After changing a `qmldir` or imports,
restart the shell:

```sh
~/dotfiles/scripts/shell-restart
```

Tune colors, spacing, radii, font defaults and durations in `theme/Theme.qml`.
Hyprland appearance lives independently in `hypr/appearance.lua`. Monitor scale
is 1 for this machine's 1366×768 display. Keyboard layout is US. The launcher
only executes installed desktop entries; it is not a shell-command runner.

## Session behavior

Hyprland launches Quickshell, Hypridle and the small polkit authentication agent.
GTK portals handle file dialogs; the Hyprland portal handles screen sharing and
screenshots. PipeWire socket activation and WirePlumber provide audio.
Hypridle requests a lock after five minutes and turns off displays after six.
It requests locking before suspend and waits for the lock using its sleep
inhibitor. There is no automatic suspend timer. Reboot, power off and logout
require a second click inside the session menu. Lock/unlock and suspend/resume remain hands-on verification steps in
`docs/verification.md`.

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
