# Titan keyboard shortcuts

Titan now uses the complete Omarchy chord set from commit
[`a85e29abb556`](https://github.com/omacom/omarchy/tree/a85e29abb556816f4644cf975e98da694b486aa8/default/hypr/bindings),
reviewed on 2026-10-03. All six files were inspected: applications, tiling,
utilities, clipboard, media and conditional voxtype. The active configuration
contains **231 bindings**, matching the reference with preinstalled application
shortcuts enabled and voxtype absent. The two Alt+Tab focus/raise pairs are
intentional. The screenshot selector temporarily adds another eight bindings.

Super means the Windows key. Changes are already active; no reboot is required.
The old Titan-only aliases have been removed so they cannot conflict with Omarchy.

## Start here

| Shortcut | Action |
| --- | --- |
| Super+Return | Kitty terminal |
| Super+Space | Titan menu |
| Super+Alt+Space | Application launcher |
| Super+K | Search every shortcut |
| Super+Shift+F | Thunar |
| Super+Shift+B | Firefox |
| Super+Shift+N | Neovim in Kitty |
| Super+A / C / V / X | Select all / copy / paste / cut |
| Super+Ctrl+V | Clipboard history |
| Super+L | Toggle this workspace between dwindle and scrolling |
| Super+Ctrl+L | Lock |
| Super+Ctrl+A | Audio/control center |
| Super+Ctrl+Shift+Space | Themes |
| Super+Escape | Session menu |
| Print | Screenshot region/window |
| Super+Print | Color picker |
| Super+Ctrl+Print | Screenshot OCR |
| Alt+Print | Start/stop recording |

Universal copy/paste sends Ctrl+Shift+C/V to Kitty, Foot, Alacritty and Ghostty;
other applications receive Ctrl+C/V. Super+V no longer toggles floating;
Super+T does. Super+L no longer locks. Super+Shift+E now opens email, and
Super+Print no longer takes a full screenshot. Use the capture menu or Ctrl+Return
while the region picker is open for a full-monitor screenshot.

## Titan implementations and explicit differences

- Quickshell owns menus, the launcher, theme/background selection, emoji picker,
  clipboard picker, calculator, reminders, keybinding help, world clock, controls
  and notifications. Omarchy's shell and helper scripts are not installed.
- Kitty, Thunar, Firefox and Neovim fulfill terminal/files/browser/editor actions.
  The exact web-app URLs from Omarchy open in Firefox windows. They require the
  user's own accounts; these bindings do not authenticate to those services.
- Super+Ctrl+A/D/P share Titan's current control center; Bluetooth and network
  share Connections. Numbered bar-panel shortcuts map 1–7 to Connections,
  Controls, Calendar, Notifications, Media, Appearance and Session. 8–9 have no
  panel, matching the reference's behavior when fewer panels exist.
- **Always awake remains authoritative:** Super+Ctrl+I and Super+Ctrl+Delete
  explain the active policy rather than enabling idle locking or switching off
  the internal display. Lid events preserve the always-on desktop. No suspend
  targets, idle timers or automatic display-off are enabled.
- Ctrl+Alt+Delete opens a close-all confirmation. It requests ordinary application
  closure only after confirmation; it does not force-kill programs.
- The background menu selects the original landscape or a solid theme color.
  Share offers screenshot-to-clipboard, files and clipboard history. Weather
  asks for a city and opens wttr.in after explicit submission. These are Titan
  equivalents, not replicas of Omarchy's complete feature interfaces.
- Herdr, Spotify, cliamp, lazydocker/Docker, Signal, Obsidian, Omawrite,
  1Password and Claude CLI are **not installed**. Their exact shortcut slots
  exist and clearly report a missing command. Installing desktop tools does not
  install these optional apps. Signal, Obsidian and lazydocker are available in
  Arch's extra repository; others need separate source/account decisions.
- Dictation shortcuts are registered only if `voxtype` exists, as in Omarchy.
  F9 starts dictation on press and stops it on release; Super+Ctrl+X toggles it.
- Keyboard-backlight keys report unavailable hardware when no backlight is
  detected. Eject requires an eject command/device. External-monitor mirroring,
  touchpad toggling and webcam controls depend on the detected hardware.

## Dependencies and state

`scripts/install-workflow` adds the reviewed official Arch packages from
`packages/workflow.txt` in a full upgrade transaction. The user installed them
on this laptop. `scripts/install-packages` includes them for a fresh Titan setup.
See [workflow.md](workflow.md) for helper interfaces and state.

Clipboard history retains at most 100 items, no larger than 1 MiB each, in
`$XDG_RUNTIME_DIR/titan/clipboard.db`; it clears at reboot. Clipboard entries
marked sensitive by wl-paste are skipped. Unmarked clipboard content is retained
until it falls out of the limit, is explicitly cleared, or the machine reboots.
The picker copies an item; Super+V pastes it. History is not committed to Git.

Window width and workspace-layout preferences persist outside the checkout.
Monitor scaling and gap/aspect preferences also produce validated runtime Lua
loaded after distribution defaults. Top-bar visibility persists independently.
Capture files use ~/Pictures/Screenshots or ~/Videos/Recordings. OCR images are
removed after text is copied. Transcoding preserves the source and refuses to
replace an existing output. Reminders currently use user-session systemd timers;
see the lifecycle limitations in workflow.md.

## Complete active shortcut reference

The following is generated from Titan's actual binding registration. Omarchy
physical codes 10–19 are the number row 1–0 on this US keyboard; 20/21 are
minus/equal, 34/35 are left/right bracket. Code 201 is retained verbatim for the
hardware shortcut. These bindings work through Hyprland's internal keycode list;
empty key/keycode fields in `hyprctl binds -j` do not mean they are unresolved.

| Shortcut | Action |
| --- | --- |
| Super+Return | Open terminal |
| Super+Shift+Return | Open browser |
| Super+Shift+F | Open files |
| Super+Alt+Shift+F | Open files-cwd |
| Super+Shift+B | Open browser |
| Super+Shift+Alt+B | Open browser-private |
| Super+Shift+N | Open editor |
| Super+Alt+Return | Open tmux |
| Super+Ctrl+Return | Open herdr |
| Super+Shift+M | Open spotify |
| Super+Shift+Alt+M | Open cliamp |
| Super+Shift+D | Open docker |
| Super+Shift+G | Open signal |
| Super+Shift+O | Open obsidian |
| Super+Shift+W | Open omawrite |
| Super+Shift+slash | Open passwords |
| Super+Shift+A | Open chatgpt |
| Super+Shift+Alt+A | Open grok |
| Super+Shift+C | Open calendar |
| Super+Shift+E | Open email |
| Super+Shift+Alt+E | Open email-new |
| Super+Shift+Y | Open youtube |
| Super+Shift+Alt+G | Open whatsapp |
| Super+Shift+Ctrl+G | Open messages |
| Super+Shift+P | Open photos |
| Super+Shift+S | Open maps |
| Super+Shift+X | Open x |
| Super+Shift+Alt+X | Open x-post |
| Super+W | Close window |
| Super+Q | Close window |
| Ctrl+Alt+Delete | Close all windows |
| Super+J | Toggle window split |
| Super+P | Pseudo window |
| Super+T | Toggle window floating/tiling |
| Super+F | Full screen |
| Super+Ctrl+F | Tiled full screen |
| Super+Alt+F | Full width |
| Super+O | Pop window out (float & pin) |
| Super+Alt+Home | Save window width |
| Super+Home | Restore window width |
| Super+L | Toggle workspace layout |
| Super+left | Focus window left |
| Super+Shift+left | Swap window left |
| Super+Shift+Alt+left | Move workspace to monitor left |
| Super+Alt+left | Move window into group left |
| Super+right | Focus window right |
| Super+Shift+right | Swap window right |
| Super+Shift+Alt+right | Move workspace to monitor right |
| Super+Alt+right | Move window into group right |
| Super+up | Focus window up |
| Super+Shift+up | Swap window up |
| Super+Shift+Alt+up | Move workspace to monitor up |
| Super+Alt+up | Move window into group up |
| Super+down | Focus window down |
| Super+Shift+down | Swap window down |
| Super+Shift+Alt+down | Move workspace to monitor down |
| Super+Alt+down | Move window into group down |
| Super+1 | Switch to workspace 1 |
| Super+Shift+1 | Move window to workspace 1 |
| Super+Shift+Alt+1 | Move window silently to workspace 1 |
| Super+2 | Switch to workspace 2 |
| Super+Shift+2 | Move window to workspace 2 |
| Super+Shift+Alt+2 | Move window silently to workspace 2 |
| Super+3 | Switch to workspace 3 |
| Super+Shift+3 | Move window to workspace 3 |
| Super+Shift+Alt+3 | Move window silently to workspace 3 |
| Super+4 | Switch to workspace 4 |
| Super+Shift+4 | Move window to workspace 4 |
| Super+Shift+Alt+4 | Move window silently to workspace 4 |
| Super+5 | Switch to workspace 5 |
| Super+Shift+5 | Move window to workspace 5 |
| Super+Shift+Alt+5 | Move window silently to workspace 5 |
| Super+6 | Switch to workspace 6 |
| Super+Shift+6 | Move window to workspace 6 |
| Super+Shift+Alt+6 | Move window silently to workspace 6 |
| Super+7 | Switch to workspace 7 |
| Super+Shift+7 | Move window to workspace 7 |
| Super+Shift+Alt+7 | Move window silently to workspace 7 |
| Super+8 | Switch to workspace 8 |
| Super+Shift+8 | Move window to workspace 8 |
| Super+Shift+Alt+8 | Move window silently to workspace 8 |
| Super+9 | Switch to workspace 9 |
| Super+Shift+9 | Move window to workspace 9 |
| Super+Shift+Alt+9 | Move window silently to workspace 9 |
| Super+0 | Switch to workspace 10 |
| Super+Shift+0 | Move window to workspace 10 |
| Super+Shift+Alt+0 | Move window silently to workspace 10 |
| Super+S | Toggle scratchpad |
| Super+grave | Toggle scratchpad |
| Super+Alt+S | Move window to scratchpad |
| Super+Shift+grave | Move window to scratchpad |
| Super+Tab | Next workspace |
| Super+Shift+Tab | Previous workspace |
| Super+Ctrl+Tab | Former workspace |
| Alt+Tab | Focus next window |
| Alt+Tab | Reveal active window on top |
| Alt+Shift+Tab | Focus previous window |
| Alt+Shift+Tab | Reveal active window on top |
| Ctrl+Alt+Tab | Focus next monitor |
| Ctrl+Alt+Shift+Tab | Focus previous monitor |
| Super+minus | Resize horizontally -100px |
| Super+equal | Resize horizontally 100px |
| Super+Shift+minus | Resize vertically -100px |
| Super+Shift+equal | Resize vertically 100px |
| Super+Alt+minus | Resize horizontally -25px |
| Super+Alt+equal | Resize horizontally 25px |
| Super+Alt+Shift+minus | Resize vertically -25px |
| Super+Alt+Shift+equal | Resize vertically 25px |
| Super+Ctrl+minus | Resize horizontally -300px |
| Super+Ctrl+equal | Resize horizontally 300px |
| Super+Ctrl+Shift+minus | Resize vertically -300px |
| Super+Ctrl+Shift+equal | Resize vertically 300px |
| Super+mouse_down | Scroll workspace forward |
| Super+mouse_up | Scroll workspace backward |
| Super+mouse:272 | Move window |
| Super+mouse:273 | Resize window |
| Super+G | Toggle window grouping |
| Super+Alt+G | Move window out of group |
| Super+Alt+Tab | Next window in group |
| Super+Ctrl+Right | Next window in group |
| Super+Alt+mouse_down | Next window in group |
| Super+Alt+Shift+Tab | Previous window in group |
| Super+Ctrl+Left | Previous window in group |
| Super+Alt+mouse_up | Previous window in group |
| Super+Alt+1 | Switch to group window 1 |
| Super+Alt+2 | Switch to group window 2 |
| Super+Alt+3 | Switch to group window 3 |
| Super+Alt+4 | Switch to group window 4 |
| Super+Alt+5 | Switch to group window 5 |
| Super+slash | Monitor scaling up |
| Super+Alt+slash | Monitor scaling down |
| Super+Space | Titan menu |
| Super+Alt+Space | Apps menu |
| Super+Ctrl+E | Emojis |
| Super+Ctrl+C | Capture menu |
| Super+Ctrl+O | Toggle menu |
| Super+Ctrl+H | Hardware menu |
| Super+Shift+code:201 | Titan menu |
| Super+Escape | System menu |
| Super+K | Keybindings |
| Super+Alt+K | Tmux keybindings |
| Super+Ctrl+K | Herdr keybindings |
| Super+Ctrl+Q | Calculator |
| XF86Calculator | Calculator |
| Super+Ctrl+Space | Background switcher |
| Super+Ctrl+S | Share |
| Super+Ctrl+period | Transcode |
| Super+Ctrl+R | Set reminder |
| Super+Ctrl+Alt+R | Show reminders |
| Super+Ctrl+Alt+E | World clock |
| Super+Shift+Ctrl+A | Agent |
| XF86PowerOff | Power menu |
| Super+Shift+Space | Toggle top bar |
| Super+Shift+Ctrl+Space | Theme menu |
| Super+BackSpace | Toggle window transparency |
| Super+Shift+BackSpace | Toggle window gaps |
| Super+Ctrl+BackSpace | Toggle single-window square aspect |
| Super+Ctrl+Alt+F | Toggle full screen desktop |
| Super+comma | Dismiss last notification |
| Super+Shift+comma | Dismiss all notifications |
| Super+Ctrl+comma | Toggle silencing notifications |
| Super+Alt+comma | Invoke last notification |
| Super+Shift+Alt+comma | Open notification history |
| Super+Ctrl+I | Toggle locking on idle (always-awake policy) |
| Super+Ctrl+N | Toggle nightlight |
| Super+Ctrl+Delete | Toggle laptop display (always-awake policy) |
| Super+Ctrl+Alt+Delete | Toggle laptop display mirroring |
| switch:on:Lid Switch | Lid closed: keep desktop awake |
| switch:off:Lid Switch | Lid opened: keep desktop awake |
| Print | Screenshot |
| Alt+Print | Screenrecording |
| Super+Alt+[ | Make webcam overlay smaller |
| Super+Alt+] | Make webcam overlay larger |
| Super+Print | Color picker |
| Super+Ctrl+Print | Extract text (OCR) from screenshot |
| Super+Shift+Ctrl+R | Clear reminders |
| Super+Ctrl+Alt+T | Show time |
| Super+Ctrl+Alt+B | Show battery remaining |
| Super+Ctrl+Alt+W | Toggle weather |
| Super+Ctrl+A | Audio |
| Super+Ctrl+B | Bluetooth |
| Super+Ctrl+D | Display |
| Super+Ctrl+Alt+D | Calendar |
| Super+Ctrl+W | Network |
| Super+Ctrl+P | Power |
| Super+Ctrl+T | Activity |
| Super+Ctrl+1 | Bar panel 1 |
| Super+Ctrl+2 | Bar panel 2 |
| Super+Ctrl+3 | Bar panel 3 |
| Super+Ctrl+4 | Bar panel 4 |
| Super+Ctrl+5 | Bar panel 5 |
| Super+Ctrl+6 | Bar panel 6 |
| Super+Ctrl+7 | Bar panel 7 |
| Super+Ctrl+8 | Bar panel 8 |
| Super+Ctrl+9 | Bar panel 9 |
| Super+Ctrl+Z | Zoom in |
| Super+Ctrl+Alt+Z | Reset zoom |
| Super+Ctrl+L | Lock system |
| Super+A | Select all |
| Super+C | Universal copy |
| Super+V | Universal paste |
| Super+X | Universal cut |
| Super+Ctrl+V | Clipboard manager |
| XF86AudioRaiseVolume | Volume up |
| XF86AudioLowerVolume | Volume down |
| Alt+XF86AudioRaiseVolume | Volume up precise |
| Alt+XF86AudioLowerVolume | Volume down precise |
| XF86MonBrightnessUp | Brightness up |
| XF86MonBrightnessDown | Brightness down |
| Shift+XF86MonBrightnessUp | Brightness maximum |
| Shift+XF86MonBrightnessDown | Brightness minimum |
| Alt+XF86MonBrightnessUp | Brightness up precise |
| Alt+XF86MonBrightnessDown | Brightness down precise |
| XF86KbdBrightnessUp | Keyboard brightness up |
| XF86KbdBrightnessDown | Keyboard brightness down |
| XF86AudioMute | Mute |
| XF86AudioMicMute | Mute microphone |
| XF86KbdLightOnOff | Keyboard backlight cycle |
| XF86TouchpadToggle | Toggle touchpad |
| XF86TouchpadOn | Enable touchpad |
| XF86TouchpadOff | Disable touchpad |
| XF86AudioNext | Next track |
| Alt+XF86AudioPlay | Next track |
| XF86AudioPause | Pause |
| XF86AudioPlay | Play |
| XF86AudioPrev | Previous track |
| Alt+Shift+XF86AudioPlay | Previous track |
| XF86Eject | Eject media |
| Shift+XF86AudioMute | Switch audio output |
| Shift+XF86AudioPause | Switch media source |
| Shift+XF86AudioPlay | Switch media source |
