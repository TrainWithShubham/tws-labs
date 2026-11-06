#!/bin/bash
set -euo pipefail
mkdir -p "$HOME/mount-audit/mnt/data" && chmod 0755 "$HOME/mount-audit/mnt/data"
real_uuid=$(blkid "$HOME/mount-audit/disks/data-disk.img" | grep -o 'UUID="[^"]*"' | cut -d'"' -f2)
echo "UUID=$real_uuid mount-audit/mnt/data ext4 defaults 0 2" > "$HOME/mount-audit/etc/fstab"
rm -f "$HOME/mount-audit/.mount-audit.passed"
