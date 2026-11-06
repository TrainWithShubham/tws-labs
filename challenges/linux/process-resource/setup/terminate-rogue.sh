#!/bin/bash
set -euo pipefail

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || exit 1
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/incident" 2>/dev/null)" || exit 1

# Complete Tasks 1 & 2
ROGUE_PID="$(cat "$INCIDENT_ROOT/run/rogue-worker.pid" 2>/dev/null || echo "")"
PARENT_PID="$(cat "$INCIDENT_ROOT/run/supervisor.pid" 2>/dev/null || echo "")"
CHILD_PID="$(cat "$INCIDENT_ROOT/run/rogue-child.pid" 2>/dev/null || echo "")"

cat << EOF > "$INCIDENT_ROOT/reports/triage.env"
ROGUE_PID=$ROGUE_PID
PARENT_PID=$PARENT_PID
ROGUE_QUEUE=reports
CHILD_PID=$CHILD_PID
BATCH_ID=9021
WORKER_NAME=report-worker
EOF
