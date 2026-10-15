. "$LAB_LIB"

[ -f config/database.env ] || fail "config/database.env does not exist."

perms=$(stat -c %a config/database.env 2>/dev/null || stat -f %Lp config/database.env 2>/dev/null || echo "")
if [ "$perms" != "600" ]; then
  fail "config/database.env permissions are $perms (expected 600)."
fi
