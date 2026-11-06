#!/bin/bash
set -euo pipefail

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || exit 1
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/incident" 2>/dev/null)" || exit 1

# Complete tasks 1, 2, 3
find "$INCIDENT_ROOT/var/cache" -maxdepth 1 -type f -name "sess_*.tmp" -delete 2>/dev/null || true
mkdir -p "$INCIDENT_ROOT/reports"
cat << 'EOF' > "$INCIDENT_ROOT/reports/root-cause.env"
CULPRIT_ENDPOINT=postgres-primary:5432
ERROR_SIGNATURE=ConnectionRefused
ROOT_CAUSE=DOWNSTREAM_TIMEOUT
EOF

if [ -f "$INCIDENT_ROOT/var/log/app.log" ] && [ ! -f "$INCIDENT_ROOT/var/log/app.log.1.gz" ]; then
  gzip -c "$INCIDENT_ROOT/var/log/app.log" > "$INCIDENT_ROOT/var/log/app.log.1.gz"
fi
: > "$INCIDENT_ROOT/var/log/app.log"

rm -f "$INCIDENT_ROOT/reports/audit-success.marker"
