# Canonical terminal artwork, shared by setup and maintenance presentations.
titan_logo() {
 case ${1:-} in
  '') [[ $# == 0 ]] || return 2 ;;
  --plain) [[ $# == 1 ]] || return 2 ;;
  -h|--help) [[ $# == 1 ]] || return 2; echo 'Usage: titan logo [--plain]'; return ;;
  *) echo 'Usage: titan logo [--plain]' >&2; return 2 ;;
 esac
 [[ -r $root/logo.txt ]] || { echo 'titan: logo.txt is missing or unreadable' >&2; return 1; }
 if [[ -t 1 && ${1:-} != --plain && -z ${NO_COLOR+x} && ${TERM:-dumb} != dumb ]]; then
  printf '\033[38;2;174;184;196m'
  cat -- "$root/logo.txt"
  printf '\033[0m\n'
 else
  cat -- "$root/logo.txt"
 fi
}
