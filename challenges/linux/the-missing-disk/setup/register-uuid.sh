#!/bin/bash
set -euo pipefail
echo "UNFORMATTED_DISK=vol-data.img" > "$HOME/disks-incident/reports/disk-discovery.env"
mkfs.ext4 -F -L app-storage "$HOME/disks-incident/devices/vol-data.img" >/dev/null 2>&1
sed -i 's/^VOLUME_UUID=.*/VOLUME_UUID=/' "$HOME/disks-incident/config/volume-registry.env" 2>/dev/null || true
