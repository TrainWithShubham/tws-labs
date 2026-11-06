#!/bin/bash
set -euo pipefail

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || exit 1
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-040/incident" 2>/dev/null)" || exit 1

mkdir -p "$INCIDENT_ROOT/reports"
cat << 'EOF' > "$INCIDENT_ROOT/reports/journal-triage.env"
ERROR_SIGNATURE=ERR_PRIVILEGED_PORT
CONFIG_SOURCE=config/report-api.env
REJECTED_PORT=80
ROOT_CAUSE=UNPRIVILEGED_PORT_VIOLATION
EOF
