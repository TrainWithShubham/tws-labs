. "$LAB_LIB"
t=$(mktemp -d) || fail "Could not create a scratch directory."
trap 'rm -rf "$t"' EXIT
run() { (cd "$t" && timeout 3 env -i PATH=/usr/bin:/bin HOME="$t" "$@" </dev/null 2>&1); }
S="$LAB_HOME/copy.sh"
[ -f "$S" ] || fail "copy.sh does not exist yet."
printf 'alpha\nbeta gamma\n' > "$t/in put.txt"
out=$(run bash "$S"); rc=$?
[ "$rc" -ne 0 ] || fail "With no arguments it should exit with a non-zero status."
printf '%s\n' "$out" | grep -qi '^usage:' || fail "With no arguments it should print a line starting with Usage:"
out=$(run bash "$S" "in put.txt"); rc=$?
[ "$rc" -ne 0 ] || fail "With only one argument it should exit with a non-zero status."
printf '%s\n' "$out" | grep -qi '^usage:' || fail "With only one argument it should print a line starting with Usage:"
out=$(run bash "$S" a b c); rc=$?
[ "$rc" -ne 0 ] || fail "With three arguments it should exit with a non-zero status."
printf '%s\n' "$out" | grep -qi '^usage:' || fail "With three arguments it should print a line starting with Usage:"
[ ! -e "$t/out put.txt" ] || fail "A bad call must not copy anything."
run bash "$S" "in put.txt" "out put.txt" >/dev/null; rc=$?
[ "$rc" -eq 0 ] || fail "With two arguments it should copy the file and exit 0 (quote \"\$1\" and \"\$2\")."
cmp -s "$t/in put.txt" "$t/out put.txt" || fail "The second argument should hold a copy of the first."
