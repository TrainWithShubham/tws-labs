#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/incident" 2>/dev/null)" || fail "Directory ~/incident does not exist."

SUPER_PID_FILE="$INCIDENT_ROOT/run/supervisor.pid"
METRICS_PID_FILE="$INCIDENT_ROOT/run/metrics-worker.pid"
ROGUE_PID_FILE="$INCIDENT_ROOT/run/rogue-worker.pid"
CHILD_PID_FILE="$INCIDENT_ROOT/run/rogue-child.pid"

[ -f "$SUPER_PID_FILE" ] || fail "Supervisor PID file missing (run/supervisor.pid)."
[ -f "$METRICS_PID_FILE" ] || fail "Metrics worker PID file missing (run/metrics-worker.pid)."

SUPER_PID="$(cat "$SUPER_PID_FILE" 2>/dev/null || echo "")"
METRICS_PID="$(cat "$METRICS_PID_FILE" 2>/dev/null || echo "")"

[ -n "$SUPER_PID" ] || fail "run/supervisor.pid is empty."
[ -n "$METRICS_PID" ] || fail "run/metrics-worker.pid is empty."

# 1. Supervisor must remain active
kill -0 "$SUPER_PID" 2>/dev/null || fail "Supervisor (PID $SUPER_PID) is not running. Do not terminate the supervisor."
ps -p "$SUPER_PID" -o cmd= 2>/dev/null | grep -q "report-supervisor" || fail "Supervisor (PID $SUPER_PID) command signature mismatch."

# 2. Healthy metrics worker must remain active
kill -0 "$METRICS_PID" 2>/dev/null || fail "Innocent worker (PID $METRICS_PID, queue=metrics) is not running. Do not kill healthy siblings."
ps -p "$METRICS_PID" -o cmd= 2>/dev/null | grep -q -- "--queue=metrics" || fail "Metrics worker (PID $METRICS_PID) is not listening on queue 'metrics'."

# 3. Rogue parent worker must be terminated
if [ -f "$ROGUE_PID_FILE" ]; then
  ROGUE_PID="$(cat "$ROGUE_PID_FILE" 2>/dev/null || echo "")"
  if [ -n "$ROGUE_PID" ]; then
    for _ in $(seq 1 5); do
      if ! kill -0 "$ROGUE_PID" 2>/dev/null; then break; fi
      sleep 0.05
    done
    if kill -0 "$ROGUE_PID" 2>/dev/null; then
      if [ -d "/proc/$ROGUE_PID" ]; then
        proc_cmd="$(tr '\0' ' ' < "/proc/$ROGUE_PID/cmdline" 2>/dev/null || ps -p "$ROGUE_PID" -o cmd= 2>/dev/null || echo "")"
        if echo "$proc_cmd" | grep -F -q "$INCIDENT_ROOT/bin/report-worker" && echo "$proc_cmd" | grep -F -q -- "--mode=runaway"; then
          fail "Rogue worker (PID $ROGUE_PID) is still running."
        fi
      fi
    fi
  fi
fi

# 4. Rogue child worker must be terminated
if [ -f "$CHILD_PID_FILE" ]; then
  CHILD_PID="$(cat "$CHILD_PID_FILE" 2>/dev/null || echo "")"
  if [ -n "$CHILD_PID" ]; then
    for _ in $(seq 1 5); do
      if ! kill -0 "$CHILD_PID" 2>/dev/null; then break; fi
      sleep 0.05
    done
    if kill -0 "$CHILD_PID" 2>/dev/null; then
      if [ -d "/proc/$CHILD_PID" ]; then
        proc_cmd="$(tr '\0' ' ' < "/proc/$CHILD_PID/cmdline" 2>/dev/null || ps -p "$CHILD_PID" -o cmd= 2>/dev/null || echo "")"
        if echo "$proc_cmd" | grep -F -q "$INCIDENT_ROOT/bin/report-worker-child"; then
          fail "Rogue child worker (PID $CHILD_PID) is still running. Both parent and child must be terminated."
        fi
      fi
    fi
  fi
fi

# 5. Global guard against runaway processes belonging to this user
if pgrep -u "$(id -u)" -f "$INCIDENT_ROOT/bin/report-worker.*--mode=runaway" >/dev/null 2>&1; then
  fail "A worker with --mode=runaway is still active on this system."
fi

if pgrep -u "$(id -u)" -f "$INCIDENT_ROOT/bin/report-worker-child" >/dev/null 2>&1; then
  fail "A report-worker-child process is still active on this system."
fi
