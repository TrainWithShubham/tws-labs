#!/bin/bash
set -euo pipefail
mkdir -p "$HOME/mount-audit/mnt/data" && chmod 0755 "$HOME/mount-audit/mnt/data"
sed -i 's/UUID=[a-f0-9-]*/UUID=00000000-0000-0000-0000-000000000000/' "$HOME/mount-audit/etc/fstab" 2>/dev/null || true
