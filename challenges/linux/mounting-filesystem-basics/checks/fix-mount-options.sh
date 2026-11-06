. "$LAB_LIB"

[ -f mount-audit/etc/fstab ] || fail "mount-audit/etc/fstab is missing."
grep -Eq "UUID=[a-f0-9-]+[[:space:]]+mount-audit/mnt/data[[:space:]]+ext4[[:space:]]+defaults(,nofail)?[[:space:]]+0[[:space:]]+2" mount-audit/etc/fstab || fail "mount-audit/etc/fstab entry must be: UUID=<uuid> mount-audit/mnt/data ext4 defaults 0 2"
