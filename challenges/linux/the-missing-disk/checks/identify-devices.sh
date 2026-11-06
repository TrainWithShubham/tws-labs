. "$LAB_LIB"

[ -f disks-incident/reports/disk-discovery.env ] || fail "disks-incident/reports/disk-discovery.env is missing."
grep -Eq "^UNFORMATTED_DISK=vol-data\.img$" disks-incident/reports/disk-discovery.env || fail "Record UNFORMATTED_DISK=vol-data.img in disks-incident/reports/disk-discovery.env."
