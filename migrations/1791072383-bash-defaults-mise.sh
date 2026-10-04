#!/usr/bin/env bash
# mise became Titan's default tool manager: hook Titan's Bash defaults (which
# activate mise) into the user's ~/.bashrc. Idempotent; only appends.
set -euo pipefail
root=${TITAN_ROOT:?}
"$root/scripts/install-bash-defaults"
