# Small mise wrappers; recipe/database operations still use development.py.
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
