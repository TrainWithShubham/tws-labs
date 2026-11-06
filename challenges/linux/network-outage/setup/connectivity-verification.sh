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

# Complete Task 2
cat << 'EOF' > "$INCIDENT_ROOT/reports/packet-trace.env"
TARGET_IP=10.0.2.100
PING_RESULT=UNREACHABLE
ERROR_MESSAGE=Network is unreachable
LAST_HOP=NONE
EOF

# Complete Task 3
cat << 'EOF' > "$INCIDENT_ROOT/reports/root-cause.env"
FAILURE_TYPE=MISSING_ROUTE
MISSING_DESTINATION=10.0.2.0/24
REQUIRED_GATEWAY=10.0.1.1
OUTGOING_INTERFACE=eth0
EOF

# Complete Task 4
cat << 'EOF' > "$INCIDENT_ROOT/config/routes.conf"
10.0.1.0/24 dev eth0 proto kernel scope link src 10.0.1.10
10.0.2.53 via 10.0.1.1 dev eth0
default via 10.0.1.1 dev eth0
EOF
cp -f "$INCIDENT_ROOT/config/routes.conf" "$INCIDENT_ROOT/run/net/routes.state"

# Reset Task 5
rm -f "$INCIDENT_ROOT/reports/audit-success.marker"
