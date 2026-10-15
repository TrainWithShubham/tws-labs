. "$LAB_LIB"

[ -f "web-server/nginx.conf" ] || fail "web-server/nginx.conf is missing"
cmp -s "web-server/nginx.conf" ".fixtures/nginx.conf" || fail "web-server/nginx.conf was modified: keep the original file intact and redirect output to nginx-updated.conf"
[ -f "nginx-updated.conf" ] || fail "nginx-updated.conf not found in current directory"
[ -s "nginx-updated.conf" ] || fail "nginx-updated.conf is empty"

cmp -s "nginx-updated.conf" <(sed 's/listen 80;/listen 8080;/' .fixtures/nginx.conf) || fail "nginx-updated.conf does not match expected configuration (listen 80 replaced with 8080)"

ran sed || fail "Use sed to update the listen directive"