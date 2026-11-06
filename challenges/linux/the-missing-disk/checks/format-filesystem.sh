. "$LAB_LIB"

[ -f disks-incident/devices/vol-data.img ] || fail "disks-incident/devices/vol-data.img is missing."
blkid disks-incident/devices/vol-data.img | grep -q 'TYPE="ext4"' || fail "vol-data.img is not formatted with an ext4 filesystem."
blkid disks-incident/devices/vol-data.img | grep -q 'LABEL="app-storage"' || fail "vol-data.img must have label app-storage."
