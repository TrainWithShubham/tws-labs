. "$LAB_LIB"
t=$(mktemp -d) || fail "Could not create a scratch directory."
trap 'rm -rf "$t"' EXIT
run() { (cd "$t" && timeout 3 env -i PATH=/usr/bin:/bin HOME="$t" "$@" </dev/null 2>&1); }
S="$LAB_HOME/nonempty.sh"
[ -f "$S" ] || fail "nonempty.sh does not exist yet."
printf 'data\n' > "$t/full.txt"
: > "$t/blank.txt"
out=$(run bash "$S" full.txt); rc=$?
[ "$out" = "ok" ] || fail "For a non-empty file it should print: ok"
[ "$rc" -eq 0 ] || fail "For a non-empty file it should exit 0."
out=$(run bash "$S" blank.txt); rc=$?
[ "$out" = "empty or missing" ] || fail "For an empty file it should print: empty or missing"
[ "$rc" -eq 3 ] || fail "For an empty file it should exit with status 3 (you got $rc)."
out=$(run bash "$S" nothing.txt); rc=$?
[ "$out" = "empty or missing" ] || fail "For a missing file it should print: empty or missing"
[ "$rc" -eq 3 ] || fail "For a missing file it should exit with status 3 (you got $rc)."
