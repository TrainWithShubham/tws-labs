#!/bin/bash
set -euo pipefail
echo "UNFORMATTED_DISK=vol-data.img" > "$HOME/disks-incident/reports/disk-discovery.env"
mkfs.ext4 -F -L app-storage "$HOME/disks-incident/devices/vol-data.img" >/dev/null 2>&1
target_uuid=$(blkid "$HOME/disks-incident/devices/vol-data.img" | grep -o 'UUID="[^"]*"' | cut -d'"' -f2)
sed -i "s/^VOLUME_UUID=.*/VOLUME_UUID=$target_uuid/" "$HOME/disks-incident/config/volume-registry.env" 2>/dev/null || true
rm -f "$HOME/disks-incident/.disk-audit.passed"
