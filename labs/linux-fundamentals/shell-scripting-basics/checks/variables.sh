. "$LAB_LIB"
[ -f vars.sh ] || fail "vars.sh does not exist yet."
grep -Eq "^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=" vars.sh || fail "Set a variable first, like NAME=Ada"
grep -q '\$[A-Za-z_{]' vars.sh || fail 'Read the variable back with a dollar sign, like $NAME'
out=$(timeout 3 bash vars.sh 2>&1)
echo "$out" | grep -Eq "^Welcome, .+!$" || fail "It should print: Welcome, <name>!"
! printf '%s\n' "$out" | grep -q '\$' || fail "It printed a literal dollar sign. Use double quotes so the variable is replaced by its value."
