#!/bin/bash
set -euo pipefail
echo "UNFORMATTED_DISK=vol-data.img" > "$HOME/disks-incident/reports/disk-discovery.env"
# Re-zero vol-data.img
dd if=/dev/zero of="$HOME/disks-incident/devices/vol-data.img" bs=1M count=1 conv=notrunc >/dev/null 2>&1
