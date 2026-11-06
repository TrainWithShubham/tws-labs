#!/bin/bash
set -euo pipefail
chmod 0755 "$HOME/deploy/scripts/backup.sh" 2>/dev/null || true
chmod 0666 "$HOME/deploy/config/db-credentials.env" 2>/dev/null || true
