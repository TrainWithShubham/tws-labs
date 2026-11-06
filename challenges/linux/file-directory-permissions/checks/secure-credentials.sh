. "$LAB_LIB"

[ -f deploy/config/db-credentials.env ] || fail "deploy/config/db-credentials.env is missing."
mode=$(stat -c '%a' deploy/config/db-credentials.env 2>/dev/null || stat -f '%Lp' deploy/config/db-credentials.env 2>/dev/null)
[ "$mode" = "600" ] || fail "deploy/config/db-credentials.env must have mode 0600 (currently $mode)."
