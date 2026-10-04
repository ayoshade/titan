# Reviewed optional services; sourced by scripts/titan-system.
titan_service_usage() {
 cat <<'USAGE'
Usage: titan service list
       titan service plan|setup|enable|disable|status docker|printing|tailscale
       titan service login|logout tailscale
       titan service receive tailscale DESTINATION
USAGE
}

titan_service_require() {
 command -v "$1" >/dev/null || { echo "titan service: $1 is not installed; see titan pkg list" >&2; return 1; }
}

titan_service_units() {
 case $1 in
  docker) printf '%s\n' docker.service docker.socket ;;
  printing) printf '%s\n' cups.service cups.socket cups.path ;;
  tailscale) printf '%s\n' tailscaled.service ;;
 esac
}

titan_service_plan() {
 local name=$1 packages units
 titan_service_require jq || return
 # Validate the whole recipe before constructing argv or beginning a transaction.
 packages=$(jq -ce --arg name "$name" '.[$name].packages |
  select(type == "array" and length > 0) |
  select(all(.[]; type == "string" and test("^[a-zA-Z0-9][a-zA-Z0-9@._+-]*$")))' \
  "$root/default/catalog/packages.json") || { echo 'titan service: Invalid package recipe' >&2; return 1; }
 units=$(titan_service_units "$name" | jq -Rsc 'split("\n")[:-1]') || return
 jq -n --argjson packages "$packages" --argjson units "$units" \
  '{schema:1,commands:[["sudo","pacman","-Syu","--needed","--"]+$packages,
   ["sudo","systemctl","enable","--now","--"]+$units]}'
}

titan_service() {
 local action=${1:-} name=${2:-} item installed active units_json plan destination
 local -a units packages
 if [[ $# == 2 && ( $name == --help || $name == -h ) && $action =~ ^(plan|setup|enable|disable|status|login|logout|receive)$ ]]; then
  titan_service_usage; return
 fi
 case $action in
  -h|--help|help) [[ $# == 1 ]] || { titan_service_usage >&2; return 2; }; titan_service_usage; return ;;
  list) [[ $# == 1 ]] || { titan_service_usage >&2; return 2; } ;;
  plan|setup|enable|disable|status)
   [[ $# == 2 && $name =~ ^(docker|printing|tailscale)$ ]] || { titan_service_usage >&2; return 2; } ;;
  login|logout) [[ $# == 2 && $name == tailscale ]] || { titan_service_usage >&2; return 2; } ;;
  receive) [[ $# == 3 && $name == tailscale ]] || { titan_service_usage >&2; return 2; } ;;
  *) titan_service_usage >&2; return 2 ;;
 esac
 if [[ $action == list ]]; then
  titan_service_require jq || return
  titan_service_require systemctl || return
  for item in docker printing tailscale; do
   mapfile -t units < <(titan_service_units "$item")
   installed=false; active=false
   if systemctl cat "${units[0]}" >/dev/null 2>&1; then installed=true; fi
   if systemctl is-active --quiet "${units[0]}" >/dev/null 2>&1; then active=true; fi
   units_json=$(printf '%s\n' "${units[@]}" | jq -Rsc 'split("\n")[:-1]') || return
   jq -n --arg name "$item" --argjson units "$units_json" --argjson installed "$installed" --argjson active "$active" \
    '{id:$name,bundle:$name,unit:$units[0],installed:$installed,active:$active} +
     (if ($units|length)>1 then {activation_units:$units[1:]} else {} end)'
  done | jq -s '{schema:1,services:.}'
  return
 fi
 mapfile -t units < <(titan_service_units "$name")
 case $action in
  plan) titan_service_plan "$name" ;;
  setup)
   plan=$(titan_service_plan "$name") || return
   titan_service_require sudo || return
   titan_service_require pacman || return
   titan_service_require systemctl || return
   mapfile -t packages < <(jq -r '.commands[0][5:][]' <<<"$plan")
   sudo pacman -Syu --needed -- "${packages[@]}" || return 1
   sudo systemctl enable --now -- "${units[@]}" || return 1 ;;
  enable|disable)
   titan_service_require systemctl || return
   titan_service_require sudo || return
   systemctl cat "${units[@]}" >/dev/null || return 1
   # Stop activation sources too, so a disabled service stays stopped.
   sudo systemctl "$action" --now -- "${units[@]}" || return 1 ;;
  status) titan_service_require systemctl || return; systemctl status --no-pager "${units[0]}" ;;
  login|logout|receive)
   titan_service_require tailscale || return
   titan_service_require sudo || return
   case $action in
    login) sudo tailscale up || return 1 ;;
    logout) sudo tailscale logout || return 1 ;;
    receive)
     destination=$3
     if [[ $destination == '~' ]]; then destination=$HOME
     elif [[ $destination == '~/'* ]]; then destination=$HOME/${destination:2}; fi
     IFS= read -r -d '' destination < <(realpath -ez -- "$destination") || return 1
     [[ -d $destination ]] || { echo 'titan service: Select an existing destination directory' >&2; return 1; }
     sudo tailscale file get -- "$destination" || return 1 ;;
   esac ;;
 esac
}
