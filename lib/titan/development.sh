# Developer recipes, mise wrappers and editable local Compose lifecycles.
titan_dev_usage() {
 cat <<'USAGE'
Usage: titan dev list
       titan dev plan|install NAME
       titan dev tools
       titan dev upgrade [--plan]
       titan dev db list
       titan dev db create NAME [--port PORT]
       titan dev db start|stop|status|logs|remove NAME

Plans require jq, run no provisioning tools and create no user state.
Installation retains full Arch upgrades and native transaction prompts.
Database configs bind to localhost; create preserves existing files.
remove uses Compose down, retaining both the config and named data volumes.
USAGE
}

titan_dev_require() {
 command -v -- "$1" >/dev/null 2>&1 || {
  printf 'titan dev: %s is not installed\n' "$1" >&2; return 1;
 }
}

titan_dev_run() {
 local code
 if "$@"; then return 0; else code=$?; fi
 [[ $code != 130 ]] || return 130
 return 1
}

titan_dev_catalog() {
 titan_dev_require jq || return
 jq -ce '
  def strings: type == "array" and all(.[]; type == "string" and (contains("\u0000") | not));
  def names: strings and all(.[]; test("^[a-zA-Z0-9][a-zA-Z0-9@._+-]*\\z"));
  if type == "object" and all(.[];
   type == "object" and
   ((if has("packages") then .packages else [] end) | names) and
   ((if has("tools") then .tools else [] end) | strings and all(.[]; length > 0)) and
   ((if has("commands") then .commands else [] end) |
    type == "array" and all(.[]; strings and length > 0 and (.[0] | length > 0))))
  then . else error("Invalid developer catalog") end
 ' "$root/default/catalog/development.json"
}

titan_dev_recipe() {
 local action=$1 name=$2 catalog commands row
 local -a argv=()
 catalog=$(titan_dev_catalog) || return 1
 commands=$(jq -ce --arg name "$name" '
  if has($name) then .[$name] |
   (if ((.packages // []) | length) > 0 then
    [["sudo","pacman","-Syu","--needed","--"] + .packages] else [] end) +
   (if ((.tools // []) | length) > 0 then
    [["mise","use","-g"] + .tools] else [] end) + (.commands // [])
  else error("Unknown environment: " + $name) end
 ' <<< "$catalog") || return 1
 if [[ $action == plan ]]; then
  jq -n --argjson commands "$commands" '{schema:1,commands:$commands}'; return
 fi
 titan_dev_require mise || return 1
 # Validate every command before the first transaction. Decode NUL-delimited
 # argv, never shell source; spaces and trailing newlines stay in one argument.
 while IFS= read -r row; do
  mapfile -d '' -t argv < <(jq -j '.[] + "\u0000"' <<< "$row")
  titan_dev_require "${argv[0]}" || return 1
  if [[ ${argv[0]} == sudo && ${argv[1]:-} == pacman ]]; then
   titan_dev_require pacman || return 1
  fi
 done < <(jq -c '.[]' <<< "$commands")
 while IFS= read -r row; do
  mapfile -d '' -t argv < <(jq -j '.[] + "\u0000"' <<< "$row")
  titan_dev_run "${argv[@]}" || return $?
 done < <(jq -c '.[]' <<< "$commands")
}

titan_dev_db_catalog() {
 titan_dev_require jq || return
 jq -ce '
  def string: type == "string" and length > 0 and (contains("\u0000") | not);
  if type == "object" and all(to_entries[];
   (.key | test("^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,79}\\z")) and
   (.value | type == "object" and (.image | string) and (.data_path | string) and
    (.port | type == "number" and . == floor and . >= 1 and . <= 65535) and
    (if has("environment") then .environment | type == "object" and all(.[]; string) else true end) and
    (if has("command") then .command | type == "array" and all(.[]; string) else true end)))
  then . else error("Invalid database catalog") end
 ' "$root/default/catalog/databases.json"
}

titan_dev_db_create() (
 local name=$1 port=$2 config=$3 state=$4 catalog data file temporary='' lock item
 local -a dependencies=(flock mkdir mktemp ln rm)
 catalog=$(titan_dev_db_catalog) || return 1
 data=$(jq -ce --arg name "$name" --arg port "$port" '
  if has($name) then .[$name] as $spec |
   (if $port == "" then $spec.port else ($port | tonumber) end) as $port |
   if $port >= 1024 and $port <= 65535 then
    {name:("titan-dev-" + $name),services:{($name):
     ({image:$spec.image,container_name:("titan-dev-" + $name),
       ports:["127.0.0.1:\($port):\($spec.port)"],restart:"unless-stopped",
       volumes:["data:" + $spec.data_path]} +
      (if $spec.environment then {environment:$spec.environment} else {} end) +
      (if $spec.command then {command:$spec.command} else {} end))},volumes:{data:{}}}
   else error("Use an unprivileged TCP port (1024–65535)") end
  else error("Unknown database: " + $name) end
 ' <<< "$catalog") || return 1
 for item in "${dependencies[@]}"; do titan_dev_require "$item" || return 1; done
 umask 077
 mkdir -p -- "$state" || return 1
 [[ ! -L $state/databases.lock ]] || { echo 'titan dev: refusing linked database lock' >&2; return 1; }
 exec {lock}>>"$state/databases.lock" || return 1
 flock -x "$lock" || return 1
 file=$config/development/databases/$name.json
 [[ ! -e $file && ! -L $file ]] || { echo 'titan dev: database configuration exists; preserving it' >&2; return 1; }
 mkdir -p -- "$config/development/databases" || return 1
 temporary=$(mktemp "$config/development/databases/.$name.json.XXXXXX") || return 1
 trap '[[ -z $temporary ]] || rm -f -- "$temporary"' EXIT
 jq . <<< "$data" >"$temporary" || return 1
 # Same-directory publication is atomic and never replaces a file created
 # concurrently by another program outside the cooperative lock.
 ln -T -- "$temporary" "$file" || return 1
 printf '%s\n' "$file"
)

titan_dev_db() {
 local action=${1:-} name='' port='' item options=1 config state catalog file
 local -a names=() command=()
 case $action in
  '') titan_dev_usage >&2; return 2 ;;
  -h|--help|help) [[ $# == 1 ]] || return 2; titan_dev_usage; return ;;
  list|create|start|stop|status|logs|remove) ;;
  *) titan_dev_usage >&2; return 2 ;;
 esac
 shift
 if [[ $# == 1 && ( $1 == -h || $1 == --help ) ]]; then titan_dev_usage; return; fi
 while (($#)); do
  item=$1; shift
  if ((options)) && [[ $item == -- ]]; then options=0
  elif ((options)) && [[ $action == create && $item == --port ]]; then
   (($#)) || { titan_dev_usage >&2; return 2; }; port=$1; shift
   [[ $port =~ ^[+-]?[0-9]+$ ]] || { titan_dev_usage >&2; return 2; }
  elif ((options)) && [[ $action == create && $item == --port=* ]]; then
   port=${item#--port=}
   [[ $port =~ ^[+-]?[0-9]+$ ]] || { titan_dev_usage >&2; return 2; }
  elif ((options)) && [[ $item == -* ]]; then titan_dev_usage >&2; return 2
  else names+=("$item"); fi
 done
 config=${XDG_CONFIG_HOME:-$HOME/.config}/titan
 state=${XDG_STATE_HOME:-$HOME/.local/state}/titan
 if [[ $action == list ]]; then
  [[ ${#names[@]} == 0 ]] || { titan_dev_usage >&2; return 2; }
  catalog=$(titan_dev_db_catalog) || return 1
  # nullglob is contained in a subshell; lists need no mkdir, lock or Docker.
  ( shopt -s nullglob dotglob
    local -a configured=()
    for file in "$config/development/databases/"*.json; do
     item=${file##*/}; configured+=("${item%.json}")
    done
    jq -n --argjson databases "$catalog" --args \
     '{schema:1,databases:$databases,configured:($ARGS.positional | sort)}' -- "${configured[@]}"
  ); return
 fi
 [[ ${#names[@]} == 1 ]] || { titan_dev_usage >&2; return 2; }
 name=${names[0]}
 [[ $name =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,79}$ ]] || {
  echo 'titan dev: use a name containing letters, numbers, dots, underscores or hyphens' >&2; return 1;
 }
 if [[ $action == create ]]; then titan_dev_db_create "$name" "$port" "$config" "$state"; return; fi
 file=$config/development/databases/$name.json
 [[ -f $file ]] || { printf 'titan dev: create the configuration first: titan dev db create %s\n' "$name" >&2; return 1; }
 titan_dev_require docker || return 1
 titan_dev_require sudo || return 1
 command=(sudo docker compose -f "$file")
 case $action in
  start) command+=(up -d) ;;
  stop) command+=(stop) ;;
  status) command+=(ps --format json) ;;
  logs) command+=(logs --tail 100) ;;
  remove) command+=(down) ;;
 esac
 titan_dev_run "${command[@]}"
}

titan_dev() {
 local action=${1:-} catalog
 case $action in
  '') titan_dev_usage >&2; return 2 ;;
  -h|--help|help) [[ $# == 1 ]] || return 2; titan_dev_usage; return ;;
 esac
 shift
 if [[ $# == 1 && ( $1 == -h || $1 == --help ) ]]; then
  case $action in list|plan|install|tools|upgrade|db) titan_dev_usage; return ;; esac
 fi
 case $action in
  list)
   [[ $# == 0 ]] || { titan_dev_usage >&2; return 2; }
   catalog=$(titan_dev_catalog) || return 1
   jq -n --argjson environments "$catalog" '{schema:1,environments:$environments}' ;;
  plan|install)
   [[ ${1:-} != -- ]] || shift
   [[ $# == 1 && $1 != -* ]] || { titan_dev_usage >&2; return 2; }
   titan_dev_recipe "$action" "$1" ;;
  tools|upgrade) titan_dev_tools "$action" "$@" ;;
  db) titan_dev_db "$@" ;;
  *) titan_dev_usage >&2; return 2 ;;
 esac
}

titan_dev_tools() {
 local action=${1:-} plan=0
 shift || return 2
 if [[ $# == 1 && ( $1 == -h || $1 == --help ) ]]; then
  if [[ $action == upgrade ]]; then echo 'Usage: titan dev upgrade [--plan]'
  else echo 'Usage: titan dev tools'; fi
  return
 fi
 if [[ $action == upgrade && $# == 1 && $1 == --plan ]]; then plan=1
 elif (($#)); then echo 'titan dev: unexpected arguments' >&2; return 2; fi
 if ((plan)); then
  command -v jq >/dev/null || { echo 'titan dev: jq is not installed' >&2; return 1; }
  jq -n '{schema:1,commands:[["mise","upgrade"]]}'; return
 fi
 command -v mise >/dev/null || { echo 'titan dev: mise is not installed' >&2; return 1; }
 # Preserve the caller's project/global configuration and release-age preference.
 if [[ $action == upgrade ]]; then mise upgrade; else mise ls; fi
}
