. "$LAB_LIB"

[ -f config/auth.token ] || fail "config/auth.token does not exist."

perms=$(stat -c %a config/auth.token 2>/dev/null || stat -f %Lp config/auth.token 2>/dev/null || echo "")
[ "$perms" = "600" ] || fail "config/auth.token permissions must be 600 (currently $perms)."

owner=$(stat -c %u config/auth.token 2>/dev/null || true)
[ "$owner" = "$UID" ] || fail "config/auth.token must be owned by the current user."
