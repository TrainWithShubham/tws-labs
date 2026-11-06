. "$LAB_LIB"

[ -d access/projects/backend ] || fail "access/projects/backend is missing."
mode=$(stat -c '%a' access/projects/backend 2>/dev/null || stat -f '%Lp' access/projects/backend 2>/dev/null)
[ "$mode" = "775" ] || fail "access/projects/backend must have mode 0775 (currently $mode)."
