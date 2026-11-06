#!/bin/bash
set -euo pipefail
chmod 0755 "$HOME/deploy/scripts/backup.sh" 2>/dev/null || true
chmod 0600 "$HOME/deploy/config/db-credentials.env" 2>/dev/null || true
chmod 0755 "$HOME/deploy/cache" 2>/dev/null || true
rm -f "$HOME/deploy/.permissions-audit.passed"
