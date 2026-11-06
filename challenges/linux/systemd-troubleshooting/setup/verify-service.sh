#!/bin/bash
set -euo pipefail

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || exit 1
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-040/incident" 2>/dev/null)" || exit 1

# Complete Task 1
mkdir -p "$INCIDENT_ROOT/reports"
cat << 'EOF' > "$INCIDENT_ROOT/reports/service-triage.env"
FAILED_SERVICE=report-api.service
ACTIVE_STATE=failed
SUB_STATE=failed
EXIT_STATUS=1/FAILURE
EOF

# Complete Task 2
cat << 'EOF' > "$INCIDENT_ROOT/reports/journal-triage.env"
ERROR_SIGNATURE=ERR_PRIVILEGED_PORT
CONFIG_SOURCE=config/report-api.env
REJECTED_PORT=80
ROOT_CAUSE=UNPRIVILEGED_PORT_VIOLATION
EOF

# Complete Task 3
sed -i 's/^Restart=no/Restart=on-failure/' "$INCIDENT_ROOT/systemd/system/report-api.service"
sed -i 's/^PORT=80/PORT=8080/' "$INCIDENT_ROOT/config/report-api.env"

# Task 4 is not complete yet
rm -f "$INCIDENT_ROOT/reports/audit-success.marker"
