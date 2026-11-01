. "$LAB_LIB"
t=$(mktemp -d) || fail "Could not create a scratch directory."
trap 'rm -rf "$t"' EXIT
run() { (cd "$t" && timeout 3 env -i PATH=/usr/bin:/bin HOME="$t" "$@" </dev/null 2>&1); }
S="$LAB_HOME/args.sh"
[ -f "$S" ] || fail "args.sh does not exist yet."
out=$(run bash "$S" a b c)
[ "$out" = "$(printf 'count=3\n- a\n- b\n- c')" ] || fail "bash args.sh a b c should print count=3 then - a, - b, - c on separate lines."
out=$(run bash "$S" "one two" three)
[ "$out" = "$(printf 'count=2\n- one two\n- three')" ] || fail "An argument with spaces is one argument: loop over \"\$@\" in double quotes."
out=$(run bash "$S")
[ "$out" = "count=0" ] || fail "With no arguments it should print only count=0."
