#!/usr/bin/env bash
# Add missing modular dotfiles to existing installs; never replace personal files.
set -euo pipefail
"${TITAN_ROOT:?}/scripts/install-user-defaults"
