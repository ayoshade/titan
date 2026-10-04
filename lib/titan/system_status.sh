# Explicit hardware/system operations; native Quickshell services own desktop state.
titan_system_usage() {
 case $1 in
  battery) echo 'Usage: titan battery' ;;
  network) printf '%s\n' 'Usage: titan network status|edit' '       titan network wifi status|on|off' '       titan network qr [--device DEVICE]' ;;
  bluetooth) printf '%s\n' 'Usage: titan bluetooth status|devices|pair' '       titan bluetooth power on|off' '       titan bluetooth connect|disconnect|trust|untrust|remove ADDRESS' ;;
  power) printf '%s\n' 'Usage: titan power list|current' '       titan power set performance|balanced|power-saver' ;;
  audio) printf '%s\n' 'Usage: titan audio status|default NODE_ID' '       titan audio volume [PERCENT] [--input]' '       titan audio mute on|off|toggle [--input]' ;;
 esac
}

titan_system_require() {
 command -v "$1" >/dev/null || { echo "titan: $1 is not installed; see titan pkg list" >&2; return 1; }
}

titan_system_run() {
 local result=0
 titan_system_require "$1" || return
 titan_system_require timeout || return
 timeout --foreground --kill-after=5s 30s "$@" || result=$?
 case $result in
  0) return 0 ;;
  130) return 130 ;;
  124|137) echo 'titan: system command timed out' >&2 ;;
 esac
 return 1
}

# Normalize decimal integers without arithmetic overflow or octal interpretation.
titan_system_integer() {
 local number=$1
 [[ $number =~ ^[+-]?[0-9]+$ ]] || return 2
 local sign=
 [[ $number != -* ]] || sign=-
 number=${number#[+-]}
 while [[ ${#number} -gt 1 && $number == 0* ]]; do number=${number:1}; done
 [[ $number != 0 ]] || sign=
 REPLY=$sign$number
}

titan_system_power_policy() {
 if [[ -e ${2:-/etc/systemd/logind.conf.d/99-titan-always-awake.conf} && $1 != performance ]]; then
  echo 'titan: This machine has the always-awake/Performance policy; change that policy explicitly first' >&2
  return 1
 fi
 return 0
}

titan_system_battery() {
 local base=${1:-/sys/class/power_supply} device kind status field value record records=
 titan_system_require jq || return
 for device in "$base"/*; do
  [[ -d $device ]] || continue
  IFS= read -r kind < "$device/type" 2>/dev/null || continue
  if [[ $kind == Battery ]]; then
   IFS= read -r status < "$device/status" 2>/dev/null || continue
   record=$(jq -cn --arg device "${device##*/}" --arg status "$status" '{device:$device,status:$status}') || return
   for field in capacity energy_now energy_full energy_full_design power_now cycle_count; do
    [[ -e $device/$field ]] || continue
    IFS= read -r value < "$device/$field" 2>/dev/null || { record=; break; }
    titan_system_integer "$value" || { echo "titan: Invalid battery $field" >&2; return 1; }
    record=$(jq -c --arg field "$field" --arg value "$REPLY" '. + {($field):($value|tonumber)}' <<< "$record") || return
   done
  elif [[ -e $device/online ]]; then
   IFS= read -r value < "$device/online" 2>/dev/null || continue
   record=$(jq -cn --arg device "${device##*/}" --argjson online "$( [[ $value == 1 ]] && echo true || echo false )" '{device:$device,online:$online}') || return
  else continue; fi
  [[ -z $record ]] || records+="$record"$'\n'
 done
 jq -s '{schema:1,batteries:map(select(has("status"))),power:map(select(has("online")))}' <<< "$records"
}

titan_system_network_status() {
 local data line character escaped field index
 local -a fields
 local records=
 titan_system_require jq || return
 data=$(titan_system_run nmcli -t -f DEVICE,TYPE,STATE device status) || return
 # nmcli escapes colons and backslashes in terse output. Decode fields without
 # requesting SSIDs, connection names or credentials.
 while IFS= read -r line; do
  [[ -n $line ]] || continue
  fields=(); field=; escaped=0
  for ((index=0; index<${#line}; index++)); do
   character=${line:index:1}
   if ((escaped)); then field+=$character; escaped=0
   elif [[ $character == '\' ]]; then escaped=1
   elif [[ $character == : ]]; then fields+=("$field"); field=
   else field+=$character; fi
  done
  fields+=("$field")
  [[ $escaped == 0 && ${#fields[@]} == 3 ]] || { echo 'titan: Invalid network status response' >&2; return 1; }
  records+=$(jq -cn --arg device "${fields[0]}" --arg type "${fields[1]}" --arg state "${fields[2]}" '{device:$device,type:$type,state:$state}') || return
  records+=$'\n'
 done <<< "$data"
 jq -s '{schema:1,devices:.}' <<< "$records"
}

titan_system() {
 local family=${1:-} action=${2:-} value argument node result=0 supplied=0 REPLY
 (($#)) || return 2
 case $family in battery|network|bluetooth|power|audio) ;; *) return 2 ;; esac
 shift
 if [[ $# == 1 && ( $1 == -h || $1 == --help ) ]]; then
  titan_system_usage "$family"; return
 fi
 # Retain help at every registered parser level, without invoking system tools.
 case $family:$action in
  battery:*|network:|network:status|network:edit|network:wifi|network:qr|bluetooth:|bluetooth:status|bluetooth:devices|bluetooth:pair|bluetooth:power|bluetooth:connect|bluetooth:disconnect|bluetooth:trust|bluetooth:untrust|bluetooth:remove|power:|power:list|power:current|power:set|audio:|audio:status|audio:default|audio:volume|audio:mute)
   for argument in "$@"; do
    if [[ $argument == -h || $argument == --help ]]; then titan_system_usage "$family"; return; fi
   done ;;
 esac
 case $family in
  battery) (($# == 0)) || { titan_system_usage "$family" >&2; return 2; }; titan_system_battery ;;
  network)
   case $action in
    status) (($# == 1)) || return 2; titan_system_network_status ;;
    wifi) [[ $# == 2 && $2 =~ ^(status|on|off)$ ]] || return 2
     value=$2; [[ $value != status ]] || value=
     if [[ -n $value ]]; then titan_system_run nmcli radio wifi "$value"; else titan_system_run nmcli radio wifi; fi ;;
    edit) (($# == 1)) || return 2; titan_system_require nmcli || return; titan_system_require nmtui || return; nmtui || result=$?; [[ $result == 0 ]] || { [[ $result != 130 ]] || return 130; return 1; } ;;
    qr) shift; supplied=0; value=
     while (($#)); do
      case $1 in
       --device) (($# >= 2)) || return 2; value=$2; shift 2 ;;
       --device=*) value=${1#--device=}; shift ;;
       *) return 2 ;;
      esac
      supplied=1
     done
     if ((supplied)); then
      [[ $value =~ ^[A-Za-z0-9_.-]+$ ]] || { echo 'titan: Invalid network device' >&2; return 1; }
      titan_system_run nmcli device wifi show-password ifname "$value"
     else titan_system_run nmcli device wifi show-password; fi ;;
    *) titan_system_usage "$family" >&2; return 2 ;;
   esac ;;
  bluetooth)
   case $action in
    status|devices) (($# == 1)) || return 2
     if [[ $action == status ]]; then titan_system_run bluetoothctl show; else titan_system_run bluetoothctl devices; fi ;;
    pair) (($# == 1)) || return 2; titan_system_require bluetoothctl || return; bluetoothctl || result=$?; [[ $result == 0 ]] || { [[ $result != 130 ]] || return 130; return 1; } ;;
    power) [[ $# == 2 && $2 =~ ^(on|off)$ ]] || return 2; titan_system_run bluetoothctl power "$2" ;;
    connect|disconnect|trust|untrust|remove)
     (($# == 2)) || return 2
     [[ $2 =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || { echo 'titan: Invalid Bluetooth address' >&2; return 1; }
     titan_system_run bluetoothctl "$action" "$2" ;;
    *) titan_system_usage "$family" >&2; return 2 ;;
   esac ;;
  power)
   case $action in
    list|current) (($# == 1)) || return 2
     if [[ $action == list ]]; then titan_system_run powerprofilesctl list; else titan_system_run powerprofilesctl get; fi ;;
    set) [[ $# == 2 && $2 =~ ^(performance|balanced|power-saver)$ ]] || return 2
     titan_system_power_policy "$2" || return
     titan_system_run powerprofilesctl set "$2" ;;
    *) titan_system_usage "$family" >&2; return 2 ;;
   esac ;;
  audio)
   case $action in
    status) (($# == 1)) || return 2; titan_system_run wpctl status -n ;;
    default) (($# == 2)) || return 2; titan_system_integer "$2" || return 2
     [[ $REPLY != -* && $REPLY != 0 ]] || { echo 'titan: Use a positive PipeWire node id' >&2; return 1; }
     titan_system_run wpctl set-default "$REPLY" ;;
    volume|mute)
     shift; node=@DEFAULT_AUDIO_SINK@; value=
     for argument in "$@"; do
      if [[ $argument == --input ]]; then node=@DEFAULT_AUDIO_SOURCE@
      elif ((supplied == 0)); then value=$argument; supplied=1
      else return 2; fi
     done
     if [[ $action == volume ]]; then
      if ((supplied == 0)); then titan_system_run wpctl get-volume "$node"; return; fi
      titan_system_integer "$value" || return 2
      [[ $REPLY != -* && ${#REPLY} -le 3 ]] && ((10#$REPLY <= 100)) || { echo 'titan: Volume must be 0–100 percent' >&2; return 1; }
      titan_system_run wpctl set-volume -l 1 "$node" "$REPLY%"
     else
      case $value in on) value=1 ;; off) value=0 ;; toggle) ;; *) return 2 ;; esac
      titan_system_run wpctl set-mute "$node" "$value"
     fi ;;
    *) titan_system_usage "$family" >&2; return 2 ;;
   esac ;;
  *) return 2 ;;
 esac
}
