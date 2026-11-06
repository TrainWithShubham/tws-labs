. "$LAB_LIB"

[ -f disks-incident/devices/vol-data.img ] || fail "disks-incident/devices/vol-data.img is missing."
target_uuid=$(blkid disks-incident/devices/vol-data.img | grep -o 'UUID="[^"]*"' | cut -d'"' -f2)
[ -n "$target_uuid" ] || fail "vol-data.img does not have a valid UUID."
[ -f disks-incident/config/volume-registry.env ] || fail "disks-incident/config/volume-registry.env is missing."
recorded_uuid=$(grep -E "^VOLUME_UUID=" disks-incident/config/volume-registry.env 2>/dev/null | cut -d'=' -f2 | tr -d '"')
[ "$recorded_uuid" = "$target_uuid" ] || fail "VOLUME_UUID in volume-registry.env ($recorded_uuid) does not match disk UUID ($target_uuid)."
