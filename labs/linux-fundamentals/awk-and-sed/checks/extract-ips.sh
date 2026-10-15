. "$LAB_LIB"

[ -f "web-server/access.log" ] || fail "web-server/access.log is missing"
cmp -s "web-server/access.log" ".fixtures/access.log" || fail "web-server/access.log was modified: restore the original file"
[ -f "client-ips.txt" ] || fail "client-ips.txt not found in current directory"
[ -s "client-ips.txt" ] || fail "client-ips.txt is empty"

cmp -s "client-ips.txt" <(awk '{print $1}' .fixtures/access.log) || fail "client-ips.txt does not match expected output from web-server/access.log"

ran awk || fail "Use awk to extract column 1"