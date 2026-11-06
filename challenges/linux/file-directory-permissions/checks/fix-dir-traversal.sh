. "$LAB_LIB"

[ -d deploy/cache ] || fail "deploy/cache is missing."
mode=$(stat -c '%a' deploy/cache 2>/dev/null || stat -f '%Lp' deploy/cache 2>/dev/null)
[ "$mode" = "755" ] || fail "deploy/cache must have mode 0755 (currently $mode)."
[ -r deploy/cache/ready.flag ] || fail "Cannot read deploy/cache/ready.flag."
