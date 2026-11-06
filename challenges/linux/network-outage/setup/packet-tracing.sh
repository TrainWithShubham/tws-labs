#!/bin/bash
set -euo pipefail

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || exit 1
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-050/incident" 2>/dev/null)" || exit 1

# Complete Task 1
mkdir -p "$INCIDENT_ROOT/reports"
cat << 'EOF' > "$INCIDENT_ROOT/reports/discovery.env"
CLIENT_IP=10.0.1.10
DNS_SERVER=10.0.2.53
RESOLVED_IP=10.0.2.100
DNS_STATUS=RESOLVED
EOF

# Reset Task 2
rm -f "$INCIDENT_ROOT/reports/packet-trace.env"
