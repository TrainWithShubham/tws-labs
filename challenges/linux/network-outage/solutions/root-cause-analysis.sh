#!/bin/bash
set -euo pipefail

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || exit 1
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-050/incident" 2>/dev/null)" || exit 1

mkdir -p "$INCIDENT_ROOT/reports"
cat << 'EOF' > "$INCIDENT_ROOT/reports/root-cause.env"
FAILURE_TYPE=MISSING_ROUTE
MISSING_DESTINATION=10.0.2.0/24
REQUIRED_GATEWAY=10.0.1.1
OUTGOING_INTERFACE=eth0
EOF
