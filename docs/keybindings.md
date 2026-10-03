# Titan keyboard shortcuts

Applied from Omarchy’s current public window/workspace conventions on 2026-10-03:
[tiling](https://github.com/omacom/omarchy/blob/quattro/default/hypr/bindings/tiling.lua),
[applications](https://github.com/omacom/omarchy/blob/quattro/default/hypr/bindings/applications.lua),
[utilities](https://github.com/omacom/omarchy/blob/quattro/default/hypr/bindings/utilities.lua).
Titan uses its own commands and Quickshell panels; Omarchy scripts are not installed.

Super means the Windows key. These shortcuts are active immediately after reload.

## Manage many terminals

| Shortcut | Action |
| --- | --- |
| Super+Return | Open a terminal |
| Super+W or Super+Q | Close the focused window |
| Alt+Tab / Alt+Shift+Tab | Focus next / previous window and raise it |
| Super+arrows | Focus a neighboring window |
| Super+Shift+arrows | Swap with a neighboring window |
| Super+1…0 | Switch to workspace 1…10 |
| Super+Shift+1…0 | Move the focused window to a workspace |
| Super+Shift+Alt+1…0 | Move it there without following |
| Super+Tab / Super+Shift+Tab | Cycle occupied workspaces forward / backward |
| Super+Ctrl+Tab | Return to the previous workspace |
| Super+Alt+S or Super+Shift+grave | Put the focused window in the scratchpad |
| Super+S or Super+grave | Show/hide scratchpad |
| Super+T or Super+V | Toggle floating/tiling |
| Super+F | Toggle full screen |
| Super+Alt+F | Toggle maximized mode |
| Super+J | Toggle tile split |
| Super+P | Toggle pseudo tiling |
| Super+minus / Super+equal | Resize horizontally |
| Super+Shift+minus / Super+Shift+equal | Resize vertically |
| Super+mouse drag / right-button drag | Move / resize |
| Super+mouse wheel | Cycle occupied workspaces |

Grouping lets compositor windows share a tab-like group. Super+G creates/toggles
a group; Super+Alt+arrows moves a window into a neighboring group;
Super+Alt+Tab / Super+Alt+Shift+Tab cycles members; Super+Alt+G removes a member.
This is separate from Kitty tabs. No bulk-close command is bound.

## Applications and desktop

| Shortcut | Action |
| --- | --- |
| Super+Shift+Return / Super+Shift+B / Super+B | Firefox |
| Super+Shift+Alt+B | Private Firefox window |
| Super+Shift+F / Super+E | Thunar |
| Super+Space / Super+Alt+Space | Quickshell application launcher |
| Super+A / Super+Ctrl+A / Super+Ctrl+D | Control center |
| Super+Ctrl+B / Super+Ctrl+W | Connections |
| Super+Ctrl+Alt+D | Calendar |
| Super+N | Notification history |
| Super+Ctrl+Shift+Space | Theme picker |
| Super+Escape / Super+Shift+E | Session menu |
| Super+Ctrl+L / Super+L | Lock screen |
| Print / Super+Print | Region / full screenshot |

The theme picker moved from Super+T so that floating matches Omarchy. Lock,
launcher, screenshots and existing Titan application aliases retain familiar
behavior. Unavailable Omarchy apps, clipboard history, capture extras, destructive
close-all and workspace-layout helpers are not assigned. Media/backlight keys
are unchanged. Every new binding has a description visible in `hyprctl binds -j`.
