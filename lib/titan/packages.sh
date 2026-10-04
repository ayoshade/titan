# Package operations; sourced by scripts/titan-packages. Plans print argv arrays.
titan_pkg_usage() {
 cat <<'USAGE'
Usage: titan pkg present|missing PACKAGE [PACKAGE…]
       titan pkg drop [--plan] PACKAGE [PACKAGE…]
       titan pkg last-upgrade [--json]
       titan pkg cache-prune [--keep N] [--plan]

present: exit 0 if all packages are installed, 1 if any are absent.
missing: exit 0 if any package is absent, 1 if all are installed.
Both return 3 if the installed-package database cannot be queried.
cache-prune retains at least two cached versions; requires pacman-contrib.
USAGE
}

titan_pkg_require() {
 command -v -- "$1" >/dev/null 2>&1 || { printf 'titan pkg: %s is not installed\n' "$1" >&2; return 1; }
}

titan_pkg_names() {
 local name
 (($#)) || { echo 'titan pkg: supply at least one package' >&2; return 2; }
 for name in "$@"; do
  [[ $name =~ ^[a-zA-Z0-9][a-zA-Z0-9@._+-]*$ ]] || {
   echo 'titan pkg: supply package names, without options or paths' >&2; return 2;
  }
 done
}

titan_pkg_argv() { jq -cn --args '$ARGS.positional' -- "$@"; }
titan_pkg_plan() { jq -n --argjson command "$(titan_pkg_argv "$@")" '{schema:1,commands:[$command]}'; }

titan_pkg_inventory() {
 local output name
 output=$(pacman -Qq) || { echo 'titan pkg: unable to query installed packages' >&2; return 3; }
 installed=()
 while IFS= read -r name; do [[ -z $name ]] || installed["$name"]=1; done <<< "$output"
}

titan_pkg_last_upgrade() {
 local timestamp log=$2
 # Only ALPM upgrade records count; command lines and unrelated text don't.
 timestamp=$(sed -nE 's/^\[([^]]+)\] \[ALPM\] upgraded .*/\1/p' "$log" | tail -n 1) || return 1
 if [[ $1 == --json ]]; then
  titan_pkg_require jq || return
  jq -n --arg timestamp "$timestamp" '{schema:1,last_upgrade:(if $timestamp == "" then null else $timestamp end)}'
 elif [[ -n $timestamp ]]; then date --date="$timestamp" '+%A, %B %d %Y at %H:%M'
 else echo 'No package upgrade recorded.'; fi
}

titan_pkg() {
 local action=${1:-} plan=0 keep=2 missing=0 item
 local -a names=() command=() selected=()
 local -A installed=() seen=()
 case $action in
  ''|-h|--help|help) [[ $# -le 1 ]] || { titan_pkg_usage >&2; return 2; }; titan_pkg_usage; return ;;
 esac
 shift
 if [[ $# == 1 && ( $1 == --help || $1 == -h ) ]]; then
  case $action in
   present|missing|drop|last-upgrade|cache-prune) titan_pkg_usage; return ;;
  esac
 fi
 case $action in
  present|missing) names=("$@"); titan_pkg_names "${names[@]}" || return ;;
  drop)
   for item in "$@"; do if [[ $item == --plan ]]; then plan=1; else names+=("$item"); fi; done
   titan_pkg_names "${names[@]}" || return
   if ((plan)); then titan_pkg_require jq || return; titan_pkg_plan sudo pacman -R -- "${names[@]}"; return; fi ;;
  last-upgrade)
   [[ $# == 0 || ( $# == 1 && $1 == --json ) ]] || { titan_pkg_usage >&2; return 2; }
   titan_pkg_last_upgrade "${1:-}" /var/log/pacman.log; return ;;
  cache-prune)
   while (($#)); do
    case $1 in
     --plan) plan=1; shift ;;
     --keep) [[ $# -ge 2 ]] || { titan_pkg_usage >&2; return 2; }; keep=$2; shift 2 ;;
     *) titan_pkg_usage >&2; return 2 ;;
    esac
   done
   [[ $keep =~ ^[1-9][0-9]{0,2}$ ]] && ((keep >= 2)) || {
    echo 'titan pkg: retain between 2 and 999 cached versions' >&2; return 2;
   }
   command=(sudo paccache -r -k "$keep")
   if ((plan)); then titan_pkg_require jq || return; titan_pkg_plan "${command[@]}"; return; fi
   titan_pkg_require paccache || { echo 'Install pacman-contrib with titan pkg add pacman-contrib' >&2; return 1; }
   titan_pkg_require sudo || return
   "${command[@]}"; return ;;
  *) titan_pkg_usage >&2; return 2 ;;
 esac
 titan_pkg_require pacman || { [[ $action != present && $action != missing ]] || return 3; return 1; }
 case $action in
  present|missing)
   titan_pkg_inventory || return
   for item in "${names[@]}"; do [[ -n ${installed[$item]:-} ]] || missing=1; done
   if [[ $action == missing ]]; then ((missing == 1))
   elif ((missing)); then return 1
   else printf '%s\n' "${names[@]}"; fi ;;
  drop)
   titan_pkg_inventory || return 1
   # Idempotent removal; preserve dependencies, configuration and pacman's prompt.
   for item in "${names[@]}"; do
    if [[ -n ${installed[$item]:-} && -z ${seen[$item]:-} ]]; then selected+=("$item"); seen[$item]=1; fi
   done
   ((${#selected[@]})) || return 0
   titan_pkg_require sudo || return
   sudo pacman -R -- "${selected[@]}" ;;
 esac
}
