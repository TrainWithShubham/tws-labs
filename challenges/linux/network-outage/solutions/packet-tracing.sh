#!/bin/bash
set -euo pipefail

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || exit 1
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-050/incident" 2>/dev/null)" || exit 1

mkdir -p "$INCIDENT_ROOT/reports"
cat << 'EOF' > "$INCIDENT_ROOT/reports/packet-trace.env"
TARGET_IP=10.0.2.100
PING_RESULT=UNREACHABLE
ERROR_MESSAGE=Network is unreachable
LAST_HOP=NONE
EOF
