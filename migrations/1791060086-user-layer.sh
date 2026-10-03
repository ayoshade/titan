#!/usr/bin/env bash
# Move user-owned choices out of the Git checkout into ~/.config/titan, settings
# from state to config, generated theme files into state, and make
# ~/.config/mimeapps.list the user's own file. Idempotent.
set -euo pipefail
root=${TITAN_ROOT:?}
xdg_config=${XDG_CONFIG_HOME:-$HOME/.config}
config=$xdg_config/titan
state=${XDG_STATE_HOME:-$HOME/.local/state}/titan
mkdir -p "$config" "$state/generated"; chmod 700 "$config" "$state"

# The user's theme/accent choice used to be written into the tracked file.
legacy=$root/config/quickshell/umbra/theme/preferences.json
if [[ ! -e $config/preferences.json && -f $legacy ]]; then
 cp "$legacy" "$config/preferences.json"; echo "  preferences → $config/preferences.json"
fi
# Settings are configuration, not machine state.
if [[ -f $state/settings.json && ! -e $config/settings.json ]]; then
 mv "$state/settings.json" "$config/settings.json"; echo "  settings → $config/settings.json"
fi
# Applications write mimeapps.list; it must not be a link into the checkout.
mime=$xdg_config/mimeapps.list
if [[ -L $mime && $(readlink -f "$mime") == "$root"/config/mimeapps.list ]]; then
 cp --remove-destination "$(readlink -f "$mime")" "$mime"; echo "  mimeapps.list is now your own file"
fi
# User override files, loaded after Titan's defaults.
[[ -e $config/hypr.lua ]] || printf -- '-- Your Hyprland overrides, loaded after Titan defaults (Lua API: see the titan skill).\n' >"$config/hypr.lua"
[[ -e $config/kitty.conf ]] || printf '# Your Kitty overrides, loaded after Titan defaults.\n' >"$config/kitty.conf"
# Theme output is regenerated into state from the current choice.
"$root/scripts/apply-theme" >/dev/null
