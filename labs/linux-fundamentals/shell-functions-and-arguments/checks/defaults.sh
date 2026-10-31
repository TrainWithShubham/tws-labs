. "$LAB_LIB"
t=$(mktemp -d) || fail "Could not create a scratch directory."
trap 'rm -rf "$t"' EXIT
run() { (cd "$t" && timeout 3 env -i PATH=/usr/bin:/bin HOME="$t" "$@" </dev/null 2>&1); }
S="$LAB_HOME/welcome.sh"
[ -f "$S" ] || fail "welcome.sh does not exist yet."
out=$(run bash "$S")
[ "$out" = "Hello, friend!" ] || fail "With no argument and no GREETING it should print: Hello, friend!"
out=$(run bash "$S" Grace)
[ "$out" = "Hello, Grace!" ] || fail "bash welcome.sh Grace should print: Hello, Grace!"
out=$(run GREETING=Hi bash "$S" Bob)
[ "$out" = "Hi, Bob!" ] || fail "GREETING=Hi bash welcome.sh Bob should print: Hi, Bob!"
out=$(run bash "$S" "")
[ "$out" = "Hello, friend!" ] || fail "An empty name should also fall back to friend (use :- with the colon)."
