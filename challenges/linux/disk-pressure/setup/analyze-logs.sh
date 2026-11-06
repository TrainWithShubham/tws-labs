#!/bin/bash
set -euo pipefail

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || exit 1
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/incident" 2>/dev/null)" || exit 1

# Complete task 1
find "$INCIDENT_ROOT/var/cache" -maxdepth 1 -type f -name "sess_*.tmp" -delete 2>/dev/null || true
rm -f "$INCIDENT_ROOT/reports/root-cause.env"
