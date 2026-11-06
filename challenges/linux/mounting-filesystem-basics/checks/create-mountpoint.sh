. "$LAB_LIB"

[ -d mount-audit/mnt/data ] || fail "Directory mount-audit/mnt/data is missing."
mode=$(stat -c '%a' mount-audit/mnt/data 2>/dev/null || stat -f '%Lp' mount-audit/mnt/data 2>/dev/null)
[ "$mode" = "755" ] || fail "mount-audit/mnt/data must have mode 0755 (currently $mode)."
