#!/bin/bash
set -euo pipefail
mkdir -p "$HOME/deploy/scripts"
chmod 0644 "$HOME/deploy/scripts/backup.sh" 2>/dev/null || true
