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

# Safe process termination helper
safe_terminate_pid() {
  local pid="$1"
  local expected_bin="$2"
  local expected_arg="${3:-}"

  if ! [[ "$pid" =~ ^[0-9]+$ ]] || [ "$pid" -le 1 ] 2>/dev/null; then
    return 0
  fi
  if ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  if [ ! -d "/proc/$pid" ]; then
    return 0
  fi

  local proc_uid=""
  [ -r "/proc/$pid/status" ] && proc_uid="$(awk '/^Uid:/ {print $2}' "/proc/$pid/status" 2>/dev/null || echo "")"
  [ -z "$proc_uid" ] && [ -d "/proc/$pid" ] && proc_uid="$(stat -c %u "/proc/$pid" 2>/dev/null || echo "")"
  if [ "$proc_uid" != "$(id -u)" ]; then
    return 0
  fi

  local proc_cmd=""
  [ -r "/proc/$pid/cmdline" ] && proc_cmd="$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || echo "")"
  [ -z "$proc_cmd" ] && proc_cmd="$(ps -p "$pid" -o cmd= 2>/dev/null || echo "")"
  if [ -z "$proc_cmd" ] || ! echo "$proc_cmd" | grep -F -q "$expected_bin"; then
    return 0
  fi

  if [ -n "$expected_arg" ]; then
    if ! echo "$proc_cmd" | grep -F -q -e "$expected_arg"; then
      return 0
    fi
  fi

  if [ -d "/proc/$pid" ]; then
    local check_cmd
    check_cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || echo "")"
    if ! echo "$check_cmd" | grep -F -q "$expected_bin"; then
      return 0
    fi
  else
    return 0
  fi

  kill -TERM "$pid" 2>/dev/null || true
  for _ in $(seq 1 20); do
    if ! kill -0 "$pid" 2>/dev/null; then return 0; fi
    sleep 0.05
  done

  if kill -0 "$pid" 2>/dev/null; then
    if [ -d "/proc/$pid" ]; then
      local recheck_cmd
      recheck_cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || echo "")"
      if echo "$recheck_cmd" | grep -F -q "$expected_bin"; then
        kill -KILL "$pid" 2>/dev/null || true
      fi
    fi
  fi

  for _ in $(seq 1 10); do
    if ! kill -0 "$pid" 2>/dev/null; then return 0; fi
    sleep 0.05
  done

  return 0
}

# Complete Task 3: Safely terminate rogue worker and child
safe_terminate_pid "$ROGUE_PID" "$INCIDENT_ROOT/bin/report-worker" "--mode=runaway"
safe_terminate_pid "$CHILD_PID" "$INCIDENT_ROOT/bin/report-worker-child" ""

# Clean up any lingering or orphaned rogue child workers
local_child_candidates="$(pgrep -u "$(id -u)" -f "$INCIDENT_ROOT/bin/report-worker-child" 2>/dev/null || true)"
for p in $local_child_candidates; do
  safe_terminate_pid "$p" "$INCIDENT_ROOT/bin/report-worker-child" "" || true
done

# Ensure supervisor and metrics worker are active
SUPER_PID="$(cat "$INCIDENT_ROOT/run/supervisor.pid" 2>/dev/null || echo "")"
if [ -z "$SUPER_PID" ] || ! kill -0 "$SUPER_PID" 2>/dev/null; then
  "$INCIDENT_ROOT/bin/report-supervisor" &
  sleep 0.1
fi

METRICS_PID="$(cat "$INCIDENT_ROOT/run/metrics-worker.pid" 2>/dev/null || echo "")"
if [ -z "$METRICS_PID" ] || ! kill -0 "$METRICS_PID" 2>/dev/null; then
  "$INCIDENT_ROOT/bin/report-worker" --queue=metrics --concurrency=2 &
  echo $! > "$INCIDENT_ROOT/run/metrics-worker.pid"
fi

# Reset Task 4 state
if [ -d "$INCIDENT_ROOT/run" ]; then
  if [ -f "$INCIDENT_ROOT/run/report-worker.pid" ]; then
    CLEAN_PID="$(cat "$INCIDENT_ROOT/run/report-worker.pid" 2>/dev/null || echo "")"
    safe_terminate_pid "$CLEAN_PID" "$INCIDENT_ROOT/bin/report-worker" "--queue=reports" || true
    rm -f "$INCIDENT_ROOT/run/report-worker.pid"
  fi
fi

local_worker_candidates="$(pgrep -u "$(id -u)" -f "$INCIDENT_ROOT/bin/report-worker.*--queue=reports" 2>/dev/null || true)"
for p in $local_worker_candidates; do
  safe_terminate_pid "$p" "$INCIDENT_ROOT/bin/report-worker" "--queue=reports" || true
done

rm -f "$INCIDENT_ROOT/reports/audit-success.marker"

cat << 'CONF_EOF' > "$INCIDENT_ROOT/config/worker.env"
# Worker runtime configuration
WORKER_MODE=runaway
BATCH_CONCURRENCY=16
MAX_MEMORY_MB=2048
LOG_LEVEL=DEBUG
CONF_EOF
