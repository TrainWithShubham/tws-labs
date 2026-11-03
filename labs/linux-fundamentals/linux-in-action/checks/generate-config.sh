. "$LAB_LIB"

[ -f config/app.env ] || fail "config/app.env does not exist."

grep -Eq '^PORT=8080$' config/app.env || fail "config/app.env must contain PORT=8080."
! grep -Eq '^PORT=80$' config/app.env || fail "config/app.env still contains PORT=80."

port_count=$(grep -c '^PORT=' config/app.env 2>/dev/null || echo 0)
[ "$port_count" -eq 1 ] || fail "config/app.env must contain exactly one PORT definition."

grep -q '^LOG_LEVEL=INFO$' config/app.env || fail "config/app.env must preserve LOG_LEVEL=INFO."
grep -q '^WORKERS=2$' config/app.env || fail "config/app.env must preserve WORKERS=2."
grep -q '^TOKEN_FILE=config/auth.token$' config/app.env || fail "config/app.env must preserve TOKEN_FILE."
