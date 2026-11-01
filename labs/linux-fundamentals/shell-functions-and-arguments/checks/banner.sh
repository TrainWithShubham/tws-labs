. "$LAB_LIB"
t=$(mktemp -d) || fail "Could not create a scratch directory."
trap 'rm -rf "$t"' EXIT
run() { (cd "$t" && timeout 3 env -i PATH=/usr/bin:/bin HOME="$t" "$@" </dev/null 2>&1); }
S="$LAB_HOME/banner.sh"
[ -f "$S" ] || fail "banner.sh does not exist yet."
out=$(run bash "$S" release)
[ "$out" = "== release ==" ] || fail "bash banner.sh release should print: == release =="
out=$(run bash "$S" "two words")
[ "$out" = "== two words ==" ] || fail "An argument with spaces should stay together: quote \"\$1\"."
out=$(run bash -c 'source "$1" seed >/dev/null 2>&1; declare -F banner >/dev/null || exit 9; banner "$2"' _ "$S" "unseen text"); rc=$?
[ "$rc" -ne 9 ] || fail "There is no function named banner in the script."
[ "$out" = "== unseen text ==" ] || fail "The banner function itself should print == <its argument> ==."
