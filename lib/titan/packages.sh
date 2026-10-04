# Package operations; sourced by scripts/titan-packages. Plans print argv arrays.
titan_pkg_usage() {
 cat <<'USAGE'
Usage: titan pkg list
       titan pkg bundle NAME [--apply]
       titan pkg search QUERY
       titan pkg installed
       titan pkg info PACKAGE [PACKAGE…]
       titan pkg add|remove|aur [--plan] PACKAGE [PACKAGE…]
       titan pkg present|missing PACKAGE [PACKAGE…]
       titan pkg drop [--plan] PACKAGE [PACKAGE…]
       titan pkg last-upgrade [--json]
       titan pkg cache-prune [--keep N] [--plan]

present: exit 0 if all packages are installed, 1 if any are absent.
missing: exit 0 if any package is absent, 1 if all are installed.
Both return 3 if the installed-package database cannot be queried.
add and bundle use full Arch upgrades; aur upgrades Arch before the AUR helper.
remove passes all requested names to pacman; drop ignores absent packages.
Plans require jq, run no package tools and create no user state.
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

titan_pkg_helper() {
 if command -v paru >/dev/null 2>&1; then printf 'paru\n'
 elif command -v yay >/dev/null 2>&1; then printf 'yay\n'
 else echo 'titan pkg: install and review paru or yay separately' >&2; return 1; fi
}

titan_pkg_catalog() {
 # Validate all executable recipe fields before producing any command arrays.
 titan_pkg_require jq || return
 jq -ce '
  def names: type == "array" and all(.[]; type == "string" and test("^[a-zA-Z0-9][a-zA-Z0-9@._+-]*\\z"));
  def strings: type == "array" and all(.[]; type == "string");
  if type == "object" and all(.[];
   type == "object" and (.packages | names) and
   ((.aur // []) | names) and ((.repositories // []) | names) and
   ((.after_install // []) | strings))
  then . else error("Invalid package catalog") end
 ' "$root/default/catalog/packages.json"
}

titan_pkg_bundle() {
 local name=$1 apply=$2 catalog recipe helper=paru item configured
 local -a packages=() aur=() repositories=() command=(sudo pacman -Syu)
 catalog=$(titan_pkg_catalog) || return 1
 recipe=$(jq -ce --arg name "$name" 'if has($name) then .[$name] else error("Unknown bundle: " + $name) end' <<< "$catalog") || return 1
 mapfile -t packages < <(jq -r '.packages[]' <<< "$recipe")
 mapfile -t aur < <(jq -r '(.aur // [])[]' <<< "$recipe")
 mapfile -t repositories < <(jq -r '(.repositories // [])[]' <<< "$recipe")
 ((${#packages[@]} == 0)) || command+=(--needed -- "${packages[@]}")
 if ((${#aur[@]})); then
  # Plans retain the existing paru fallback; apply must have a real helper.
  if ((apply)); then helper=$(titan_pkg_helper) || return 1
  elif command -v paru >/dev/null 2>&1; then helper=paru
  elif command -v yay >/dev/null 2>&1; then helper=yay; fi
 fi
 if ((!apply)); then
  jq -n --arg name "$name" --argjson recipe "$recipe" \
   --argjson command "$(titan_pkg_argv "${command[@]}")" --arg helper "$helper" '
   {schema:1,bundle:$name,commands:([$command] +
    (if (($recipe.aur // []) | length) > 0 then [([$helper,"-S","--needed","--"] + $recipe.aur)] else [] end)),
    repositories:($recipe.repositories // []),after_install:($recipe.after_install // [])}'
  return
 fi
 titan_pkg_require pacman || return 1
 titan_pkg_require sudo || return 1
 if ((${#repositories[@]})); then
  titan_pkg_require pacman-conf || return 1
  configured=$(pacman-conf --repo-list) || return 1
  for item in "${repositories[@]}"; do
   if ! grep -Fxq -- "$item" <<< "$configured"; then
    printf 'titan pkg: enable required repository explicitly first: %s\n' "$item" >&2; return 1
   fi
  done
 fi
 "${command[@]}" || return 1
 ((${#aur[@]} == 0)) || "$helper" -S --needed -- "${aur[@]}" || return 1
}

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
 local action=${1:-} plan=0 keep=2 missing=0 item options=1 apply=0 helper catalog
 local -a names=() command=() selected=()
 local -A installed=() seen=()
 case $action in
  '') titan_pkg_usage >&2; return 2 ;;
  -h|--help|help) [[ $# == 1 ]] || { titan_pkg_usage >&2; return 2; }; titan_pkg_usage; return ;;
 esac
 shift
 if [[ $# == 1 && ( $1 == --help || $1 == -h ) ]]; then
  case $action in
   list|bundle|search|installed|info|add|remove|aur|present|missing|drop|last-upgrade|cache-prune) titan_pkg_usage; return ;;
  esac
 fi
 case $action in
  list)
   [[ $# == 0 ]] || { titan_pkg_usage >&2; return 2; }
   catalog=$(titan_pkg_catalog) || return 1
   jq -n --argjson bundles "$catalog" '{schema:1,bundles:$bundles}'; return ;;
  bundle)
   for item in "$@"; do
    if ((options)) && [[ $item == -- ]]; then options=0
    elif ((options)) && [[ $item == --apply ]]; then apply=1
    elif ((options)) && [[ $item == -* ]]; then titan_pkg_usage >&2; return 2
    else names+=("$item"); fi
   done
   [[ ${#names[@]} == 1 ]] || { titan_pkg_usage >&2; return 2; }
   titan_pkg_bundle "${names[0]}" "$apply"; return ;;
  installed)
   [[ $# == 0 ]] || { titan_pkg_usage >&2; return 2; }
   titan_pkg_require pacman || return 1
   pacman -Q || return 1; return ;;
  search)
   [[ ${1:-} != -- ]] || shift
   [[ $# == 1 ]] || { titan_pkg_usage >&2; return 2; }
   titan_pkg_require pacman || return 1
   pacman -Ss -- "$1" || return 1; return ;;
  info|add|remove|aur)
   for item in "$@"; do
    if ((options)) && [[ $item == -- ]]; then options=0
    elif ((options)) && [[ $item == --plan && $action != info ]]; then plan=1
    else names+=("$item"); fi
   done
   titan_pkg_names "${names[@]}" || return
   case $action in
    info)
     titan_pkg_require pacman || return 1
     pacman -Si -- "${names[@]}" || return 1; return ;;
    add) command=(sudo pacman -Syu --needed -- "${names[@]}") ;;
    remove) command=(sudo pacman -R -- "${names[@]}") ;;
    aur)
     helper=$(titan_pkg_helper) || return 1
     if ((plan)); then
      titan_pkg_require jq || return 1
      jq -n --argjson upgrade "$(titan_pkg_argv sudo pacman -Syu)" \
       --argjson install "$(titan_pkg_argv "$helper" -S --needed -- "${names[@]}")" \
       '{schema:1,commands:[$upgrade,$install]}'; return
     fi
     command=(sudo pacman -Syu) ;;
   esac
   if ((plan)); then titan_pkg_require jq || return 1; titan_pkg_plan "${command[@]}"; return; fi
   titan_pkg_require pacman || return 1
   titan_pkg_require sudo || return 1
   "${command[@]}" || return 1
   [[ $action != aur ]] || "$helper" -S --needed -- "${names[@]}" || return 1
   return ;;
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
