#!/usr/bin/env bash
# Titan's public commands moved from scripts/ to bin/ (docs/layout-plan.md).
# Repoint the checkout's ~/.local/bin links and report user files that still
# use the old paths; they keep working through compatibility links for now.
set -euo pipefail
root=${TITAN_ROOT:?}
for name in titan titan-shell titan-session; do
 link=$HOME/.local/bin/$name
 if [[ -L $link && $(readlink "$link") == "$root/scripts/$name" && -x $root/bin/$name ]]; then
  ln -sfn "$root/bin/$name" "$link"; echo "  $link → $root/bin/$name"
 fi
done
if refs=$("$root/scripts/legacy-paths"); then :; else
 echo "  These files call scripts/NAME; change it to bin/NAME before the compatibility links are removed:"
 printf '%s\n' "$refs" | sed 's/^/    /'
fi
