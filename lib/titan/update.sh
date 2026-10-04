# Update readiness and stage records. Sourced by bin/titan; no polling or logs
# of subprocess output. Inspection never creates state or contacts a remote.
titan_update_usage() {
 cat <<'USAGE'
Usage: titan update [--no-system]
       titan update check [--json] [--no-system]
       titan update status [--json]

check exits 0 when ready, 1 when blocked; invalid arguments exit 2.
status reports an interrupted attempt when its update lock is no longer held.
USAGE
}

titan_update_busy() {
 local fd
 [[ ! -L $state/update.lock ]] || return 2
 [[ -e $state/update.lock ]] || return 1
 [[ -f $state/update.lock ]] || return 2
 # Read-only open: do not create/truncate the lock during inspection.
 exec {fd}<"$state/update.lock" || return 2
 if flock -n "$fd"; then exec {fd}<&-; return 1; fi
 exec {fd}<&-
 return 0
}

titan_update_checkout() { [[ -e $root/.git ]]; }

titan_update_check() {
 local system=$1 json=$2 owned=${3:-0} ready=1 id result free='' packages='' command path busy_code
 local -a checks=() commands=(flock df jq pacman)
 titan_update_checkout && commands+=(git)
 ((system)) && commands+=(sudo)
 for command in "${commands[@]}"; do
  if command -v "$command" >/dev/null 2>&1; then
   checks+=("dependency-$command" pass "$command is available")
  else checks+=("dependency-$command" fail "Install $command through a reviewed full Arch upgrade"); ready=0; fi
 done
 if command -v snapper >/dev/null 2>&1 && result=$(snapper list-configs 2>/dev/null); then
  if grep -q '^root ' <<< "$result"; then
   if command -v sudo >/dev/null 2>&1; then checks+=(snapshot pass 'A root snapshot will be taken before updates')
   else checks+=(snapshot fail 'Root snapshots require sudo, including with --no-system'); ready=0; fi
  else checks+=(snapshot warn 'No root snapshot configured; this update will continue without one'); fi
 else checks+=(snapshot warn 'Root snapshot configuration is unavailable; this update will continue without one'); fi
 if command -v pacman >/dev/null 2>&1; then
  if packages=$(pacman -Qq 2>/dev/null); then
   if [[ $'\n'$packages$'\n' == *$'\njq\n'* ]]; then
    checks+=(package-jq pass 'jq is installed through pacman')
   else checks+=(package-jq fail 'Install the required jq package: sudo pacman -Syu --needed jq'); ready=0; fi
  else checks+=(package-database fail 'Cannot query installed packages; inspect pacman diagnostics'); ready=0; fi
 fi
 if [[ -e /var/lib/pacman/db.lck || -L /var/lib/pacman/db.lck ]]; then
  checks+=(pacman-lock fail 'pacman has a lock; wait for its transaction and inspect it before retrying'); ready=0
 else checks+=(pacman-lock pass 'No pacman lock is present'); fi
 if command -v df >/dev/null 2>&1; then
  if free=$(df --output=avail --block-size=1 / 2>/dev/null); then
   free=${free##*$'\n'}; free=${free//[[:space:]]/}
  else free=''; fi
 fi
 if [[ ! $free =~ ^[0-9]{1,15}$ ]]; then
  checks+=(root-space fail 'Cannot measure free space on /'); ready=0; free=''
 elif ((10#$free < 2147483648)); then
  checks+=(root-space fail 'At least 2 GiB free on / is required; review disk usage before retrying'); ready=0
 else checks+=(root-space pass 'At least 2 GiB free on /'); fi
 if ((owned)); then checks+=(update-lock pass 'This update owns the lock')
 elif command -v flock >/dev/null 2>&1; then
  busy_code=0; titan_update_busy || busy_code=$?
  case $busy_code in
   0) checks+=(update-lock fail 'Another update or its worker holds the lock; wait before retrying'); ready=0 ;;
   1) checks+=(update-lock pass 'No update holds the lock') ;;
   *) checks+=(update-lock fail 'Cannot inspect the update lock; check its type and permissions'); ready=0 ;;
  esac
 fi
 path=$state
 if [[ $path == /* ]]; then
  while [[ ! -e $path && ! -L $path && $path != / ]]; do path=${path%/*}; [[ -n $path ]] || path=/; done
 else path=''; fi
 if [[ -d $path && -w $path && -x $path && ! -L $state/update.json &&
       ( ! -e $state/update.json || -f $state/update.json ) ]]; then
  checks+=(state-storage pass 'Update state can be written')
 else checks+=(state-storage fail 'Check update state directory permissions and linked record paths'); ready=0; fi
 if titan_update_checkout && command -v git >/dev/null 2>&1; then
  if result=$(GIT_OPTIONAL_LOCKS=0 git -C "$root" status --porcelain --untracked-files=no 2>/dev/null); then
   if [[ -n $result ]]; then
    checks+=(checkout fail 'The Titan checkout has tracked changes; commit or move them before updating'); ready=0
   else checks+=(checkout pass 'The Titan checkout has no tracked changes'); fi
   if git -C "$root" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
    checks+=(upstream pass 'The checkout has a tracking branch; updates use git pull --ff-only')
   else checks+=(upstream warn 'No tracking branch; this update will skip git pull'); fi
  else checks+=(checkout fail 'Cannot inspect the Titan checkout'); ready=0; fi
 fi
 if ((json)); then
  command -v jq >/dev/null 2>&1 || { echo 'titan update: JSON output requires jq; try update check without --json' >&2; return 1; }
  jq -n --argjson ready "$ready" --argjson system "$system" --arg free "$free" --args '
   {schema:1,ready:($ready==1),system:($system==1),minimum_root_bytes:2147483648,
    available_root_bytes:(if $free=="" then null else ($free|tonumber) end),
    checks:[$ARGS.positional|range(0;length;3) as $i|
     {id:.[$i],status:.[$i+1],message:.[$i+2]}]}' -- "${checks[@]}"
 else
  for ((id=0; id<${#checks[@]}; id+=3)); do
   printf '%s %s: %s\n' "${checks[id+1]^^}" "${checks[id]}" "${checks[id+2]}"
  done
 fi
 ((ready))
}

titan_update_status() {
 local json=$1 busy=false code=0 record
 command -v jq >/dev/null 2>&1 && command -v flock >/dev/null 2>&1 || {
  echo 'titan update: status requires jq and flock' >&2; return 1;
 }
 titan_update_busy || code=$?
 case $code in 0) busy=true ;; 1) ;; *) echo 'titan update: cannot inspect update lock' >&2; return 1 ;; esac
 record='{"schema":1,"status":"idle","stage":null,"exit_code":null}'
 if [[ -e $state/update.json || -L $state/update.json ]]; then
  [[ -f $state/update.json && ! -L $state/update.json ]] || { echo 'titan update: invalid update record path' >&2; return 1; }
  record=$(jq -ce 'select(.schema==1 and
   (.status=="running" or .status=="failed" or .status=="completed") and
   (.stage|type)=="string")' "$state/update.json") || {
   echo 'titan update: invalid update record; inspect it before retrying' >&2; return 1;
  }
 fi
 record=$(jq -c --argjson busy "$busy" '
  . + {busy:$busy} | if .status=="running" and ($busy|not) then
   .status="interrupted" | .recovery="Inspect pacman and run titan update check before retrying; never remove an active pacman lock."
  elif .status=="failed" then
   .recovery="Review the failed stage, inspect pacman and run titan update check before retrying."
  else . end' <<< "$record")
 if ((json)); then printf '%s\n' "$record"
 else jq -r '"Update: \(.status); stage: \(.stage // "none"); busy: \(.busy)",
  (if .exit_code!=null then "Exit code: \(.exit_code)" else empty end),
  (.recovery // empty)' <<< "$record"; fi
}

titan_update_record() {
 local status=$1 code=${2:-null} temporary
 temporary=$(mktemp "$state/.update.XXXXXX") || return
 if ! jq -n --arg status "$status" --arg stage "$update_stage" --arg started "$update_started" \
  --arg updated "$(date -Is)" --argjson code "$code" --argjson pid "$$" --argjson system "$update_system" \
  '{schema:1,status:$status,stage:$stage,pid:$pid,started_at:$started,updated_at:$updated,
    system:($system==1),exit_code:$code}' >"$temporary"; then rm -f -- "$temporary"; return 1; fi
 mv -fT -- "$temporary" "$state/update.json"
}

titan_update_stage() {
 update_stage=$1
 titan_update_record running
 printf 'Update stage: %s\n' "$update_stage"
}

titan_update_finish() {
 local code=$1
 trap - EXIT INT TERM
 if ((code)); then
  titan_update_record failed "$code" || echo 'titan update: could not save failure status' >&2
  printf 'titan update: stopped at %s (exit %s). Run titan update status, inspect the failed command, then titan update check.\n' "$update_stage" "$code" >&2
 else titan_update_record completed 0 || return 1; fi
}

titan_update_run() (
 # A subshell bounds traps and the inherited worker lock to this update.
 local update_system=$1 update_stage=preflight update_started checkout=0 before after
 titan_update_check "$update_system" 0 || exit 1
 umask 077
 mkdir -p "$state"
 [[ ! -L $state/update.lock ]] || { echo 'titan update: refusing linked lock' >&2; exit 1; }
 exec 9>>"$state/update.lock"
 flock -n 9 || { echo 'titan update: another update is running' >&2; exit 1; }
 # Recheck mutable prerequisites after acquiring the update lock.
 titan_update_check "$update_system" 0 1 || exit 1
 update_started=$(date -Is)
 titan_update_record running
 trap 'titan_update_finish "$?"' EXIT
 trap 'exit 130' INT
 trap 'exit 143' TERM
 titan_update_checkout && checkout=1
 printf 'Titan %s — update\n' "$(cat "$root/version")"
 titan_update_stage snapshot
 if command -v snapper >/dev/null && snapper list-configs 2>/dev/null | grep -q '^root '; then
  sudo snapper -c root create -c number -d "titan update $(date -Is)"
  echo 'Snapshot taken.'
 else echo 'No root snapshot configured (run scripts/install-snapshots to enable); continuing.'; fi
 before=$( ((checkout)) && git -C "$root" rev-parse HEAD || cat "$root/version")
 titan_update_stage checkout
 if ((checkout)) && git -C "$root" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then git -C "$root" pull --ff-only; fi
 if ((update_system)); then
  titan_update_stage packages
  sudo pacman -Syu  # Keep pacman's confirmation and the full-upgrade contract.
 fi
 titan_update_stage migrations
 migrate
 titan_update_stage skills
 "$root/scripts/install-agent-skills" || echo 'titan: custom skill conflict; resolve it and run titan skills' >&2
 titan_update_stage doctor
 if ! "$root/scripts/doctor" >/dev/null; then
  echo 'titan update: health checks failed; run titan doctor for details' >&2
  exit 1
 fi
 echo 'Doctor: OK'
 after=$( ((checkout)) && git -C "$root" rev-parse HEAD || cat "$root/version")
 titan_update_stage shell
 if [[ $after != "$before" ]] && { ((!checkout)) || ! git -C "$root" diff --quiet "$before" HEAD -- config/quickshell; }; then
  "$root/bin/titan-shell" restart
  echo 'Shell restarted.'
 fi
 [[ -d /usr/lib/modules/$(uname -r) ]] || echo 'The running kernel was updated: reboot when convenient.'
 titan_update_stage hooks
 "$root/scripts/titan-hooks" hook post-update || true
 update_stage=complete
 printf 'Titan %s update completed.\n' "$(cat "$root/version")"
)

titan_update() {
 local action=run system=1 json=0 item
 case ${1:-} in
  check|status) action=$1; shift ;;
  -h|--help|help) [[ $# == 1 ]] || return 2; titan_update_usage; return ;;
 esac
 for item in "$@"; do
  case $item in
   --no-system) [[ $action != status ]] || { titan_update_usage >&2; return 2; }; system=0 ;;
   --json) [[ $action != run ]] || { titan_update_usage >&2; return 2; }; json=1 ;;
   *) titan_update_usage >&2; return 2 ;;
  esac
 done
 case $action in
  check) titan_update_check "$system" "$json" ;;
  status) titan_update_status "$json" ;;
  run) titan_update_run "$system" ;;
 esac
}
