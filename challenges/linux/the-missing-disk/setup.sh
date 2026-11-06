#!/bin/bash
set -euo pipefail

mkdir -p "$HOME/disks-incident/devices" "$HOME/disks-incident/reports" "$HOME/disks-incident/config"

# 1. Provision formatted virtual disks
truncate -s 5M "$HOME/disks-incident/devices/vol-primary.img"
mkfs.ext4 -F -L app-os "$HOME/disks-incident/devices/vol-primary.img" >/dev/null 2>&1

truncate -s 5M "$HOME/disks-incident/devices/vol-logs.img"
mkfs.ext4 -F -L app-logs "$HOME/disks-incident/devices/vol-logs.img" >/dev/null 2>&1

# 2. Provision unformatted raw virtual disk
truncate -s 5M "$HOME/disks-incident/devices/vol-data.img"
# Zero-fill to ensure no filesystem signature
dd if=/dev/zero of="$HOME/disks-incident/devices/vol-data.img" bs=1M count=1 conv=notrunc >/dev/null 2>&1

# 3. Clean reports & config
rm -f "$HOME/disks-incident/reports/disk-discovery.env"
cat << 'EOF' > "$HOME/disks-incident/config/volume-registry.env"
# Storage Volume Registration
PRIMARY_VOLUME=vol-primary.img
LOGS_VOLUME=vol-logs.img
VOLUME_UUID=
EOF
chmod 0644 "$HOME/disks-incident/config/volume-registry.env"

rm -f "$HOME/disks-incident/.disk-audit.passed"

# 4. Verification tool
cat << 'VERIFY_EOF' > "$HOME/disks-incident/verify-disks"
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# 1. Verify discovery report
if [ ! -f "reports/disk-discovery.env" ] || ! grep -Eq "^UNFORMATTED_DISK=vol-data\.img$" reports/disk-discovery.env; then
  echo "FAIL: reports/disk-discovery.env does not record UNFORMATTED_DISK=vol-data.img." >&2
  exit 1
fi

# 2. Verify filesystem format on vol-data.img
if ! blkid devices/vol-data.img | grep -q 'TYPE="ext4"'; then
  echo "FAIL: devices/vol-data.img is not formatted as ext4." >&2
  exit 1
fi

if ! blkid devices/vol-data.img | grep -q 'LABEL="app-storage"'; then
  echo "FAIL: devices/vol-data.img is not labeled app-storage." >&2
  exit 1
fi

# 3. Verify registered UUID
actual_uuid=$(blkid devices/vol-data.img | grep -o 'UUID="[^"]*"' | cut -d'"' -f2)
registered_uuid=$(grep -E "^VOLUME_UUID=" config/volume-registry.env 2>/dev/null | cut -d'=' -f2 | tr -d '"')

if [ -z "$actual_uuid" ] || [ "$actual_uuid" != "$registered_uuid" ]; then
  echo "FAIL: config/volume-registry.env UUID ($registered_uuid) does not match disk UUID ($actual_uuid)." >&2
  exit 1
fi

cat << 'MARKER_EOF' > ".disk-audit.passed"
{
  "status": "PASSED",
  "verified_at": "2026-11-05T12:00:00Z",
  "audit": "the-missing-disk"
}
MARKER_EOF

echo "SUCCESS: All storage volumes formatted, labeled, and registered."
exit 0
VERIFY_EOF
chmod 0755 "$HOME/disks-incident/verify-disks"
