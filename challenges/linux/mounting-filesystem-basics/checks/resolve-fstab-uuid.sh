. "$LAB_LIB"

[ -f mount-audit/disks/data-disk.img ] || fail "mount-audit/disks/data-disk.img is missing."
real_uuid=$(blkid mount-audit/disks/data-disk.img | grep -o 'UUID="[^"]*"' | cut -d'"' -f2)
[ -n "$real_uuid" ] || fail "Cannot determine UUID of data-disk.img."
[ -f mount-audit/etc/fstab ] || fail "mount-audit/etc/fstab is missing."
grep -q "UUID=$real_uuid" mount-audit/etc/fstab || fail "mount-audit/etc/fstab does not contain the correct UUID ($real_uuid)."
