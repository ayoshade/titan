#!/usr/bin/env bash
# Existing installs were set up before `titan setup` and the Welcome screen
# existed: record both as done so neither runs again on this machine.
set -euo pipefail
root=${TITAN_ROOT:?}
state=${XDG_STATE_HOME:-$HOME/.local/state}/titan
mkdir -p "$state"
[[ -e $state/setup-version ]] || { cat "$root/version" >"$state/setup-version"; echo "  setup recorded"; }
[[ -e $state/welcome-done ]] || { date -Is >"$state/welcome-done"; echo "  welcome recorded"; }
