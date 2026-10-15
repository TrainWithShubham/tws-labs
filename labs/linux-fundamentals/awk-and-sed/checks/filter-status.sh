. "$LAB_LIB"

[ -f "web-server/access.log" ] || fail "web-server/access.log is missing"
cmp -s "web-server/access.log" ".fixtures/access.log" || fail "web-server/access.log was modified: restore the original file"
[ -f "server-errors.txt" ] || fail "server-errors.txt not found in current directory"
[ -s "server-errors.txt" ] || fail "server-errors.txt is empty"

cmp -s "server-errors.txt" <(awk '$9 == 500 {print $1, $7}' .fixtures/access.log) || fail "server-errors.txt does not match expected output (IP and path for status 500)"

ran awk || fail "Use awk to filter HTTP 500 records"
ran_re "500" || fail "Specify status code 500 in your awk condition"