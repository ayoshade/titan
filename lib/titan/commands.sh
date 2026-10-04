# Dependency predicates; sourced by scripts/titan-commands.
titan_commands() {
 local action=${1:-} name missing=0
 case $action in
  -h|--help|help)
   [[ $# == 1 ]] || return 2
   printf 'Usage: titan cmd present|missing COMMAND [COMMAND…]\n'; return ;;
  present|missing) shift ;;
  *) printf 'Usage: titan cmd present|missing COMMAND [COMMAND…]\n' >&2; return 2 ;;
 esac
 (($#)) || { echo 'titan cmd: supply at least one command' >&2; return 2; }
 for name in "$@"; do
  [[ -n $name && $name != -* ]] || { echo 'titan cmd: supply nonempty command names or executable paths, without options' >&2; return 2; }
 done
 # Check literal names, never execute them or interpret them as shell source.
 for name in "$@"; do command -v -- "$name" >/dev/null 2>&1 || missing=1; done
 if [[ $action == present ]]; then ((missing == 0)); else ((missing == 1)); fi
}
