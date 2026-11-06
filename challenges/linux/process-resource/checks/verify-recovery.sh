#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/incident" 2>/dev/null)" || fail "Directory ~/incident does not exist."

MARKER="$INCIDENT_ROOT/reports/audit-success.marker"
[ -f "$MARKER" ] || fail "incident/reports/audit-success.marker not found. Run ./bin/audit-processes."

grep -Fxq "PROCESS_INCIDENT=RESOLVED" "$MARKER" || fail "Audit marker missing PROCESS_INCIDENT=RESOLVED."
grep -Fxq "ROGUE_WORKERS=NONE" "$MARKER" || fail "Audit marker missing ROGUE_WORKERS=NONE."
grep -Fxq "SUPERVISOR_STATUS=HEALTHY" "$MARKER" || fail "Audit marker missing SUPERVISOR_STATUS=HEALTHY."
grep -Fxq "METRICS_WORKER=ACTIVE" "$MARKER" || fail "Audit marker missing METRICS_WORKER=ACTIVE."
grep -Fxq "REPORT_WORKER=ACTIVE" "$MARKER" || fail "Audit marker missing REPORT_WORKER=ACTIVE."
grep -Fxq "CONFIG_INTEGRITY=VERIFIED" "$MARKER" || fail "Audit marker missing CONFIG_INTEGRITY=VERIFIED."
grep -Fxq "AUDITED_BY=process_audit_v1" "$MARKER" || fail "Audit marker missing AUDITED_BY=process_audit_v1."

# Independent verification of real machine state
SUPER_PID="$(cat "$INCIDENT_ROOT/run/supervisor.pid" 2>/dev/null || echo "")"
[ -n "$SUPER_PID" ] || fail "Independent check failed: run/supervisor.pid is missing or empty."
kill -0 "$SUPER_PID" 2>/dev/null || fail "Independent check failed: supervisor (PID $SUPER_PID) is not active."
ps -p "$SUPER_PID" -o cmd= 2>/dev/null | grep -q "report-supervisor" || fail "Independent check failed: supervisor PID $SUPER_PID command signature mismatch."

METRICS_PID="$(cat "$INCIDENT_ROOT/run/metrics-worker.pid" 2>/dev/null || echo "")"
[ -n "$METRICS_PID" ] || fail "Independent check failed: run/metrics-worker.pid is missing or empty."
kill -0 "$METRICS_PID" 2>/dev/null || fail "Independent check failed: metrics worker (PID $METRICS_PID) is not active."
ps -p "$METRICS_PID" -o cmd= 2>/dev/null | grep -q -- "--queue=metrics" || fail "Independent check failed: metrics worker is not on queue 'metrics'."

CONF="$INCIDENT_ROOT/config/worker.env"
[ -f "$CONF" ] || fail "Independent check failed: config/worker.env is missing."
grep -Eq "^[[:space:]]*WORKER_MODE=standard([[:space:]]|$)" "$CONF" || fail "Independent check failed: config/worker.env does not set WORKER_MODE=standard."
grep -Eq "^[[:space:]]*BATCH_CONCURRENCY=2([[:space:]]|$)" "$CONF" || fail "Independent check failed: config/worker.env does not set BATCH_CONCURRENCY=2."
grep -Eq "^[[:space:]]*MAX_MEMORY_MB=512([[:space:]]|$)" "$CONF" || fail "Independent check failed: config/worker.env does not set MAX_MEMORY_MB=512."

WORKER_PID="$(cat "$INCIDENT_ROOT/run/report-worker.pid" 2>/dev/null || echo "")"
[ -n "$WORKER_PID" ] || fail "Independent check failed: clean report-worker was not started (run/report-worker.pid missing)."
kill -0 "$WORKER_PID" 2>/dev/null || fail "Independent check failed: report-worker (PID $WORKER_PID) is not running."

WORKER_CMD="$(ps -p "$WORKER_PID" -o cmd= 2>/dev/null || echo "")"
echo "$WORKER_CMD" | grep -q -- "--queue=reports" || fail "Independent check failed: report-worker is not listening on queue 'reports'."
echo "$WORKER_CMD" | grep -q -- "--mode=standard" || fail "Independent check failed: report-worker is not running with --mode=standard."

if pgrep -u "$(id -u)" -f "$INCIDENT_ROOT/bin/report-worker.*--mode=runaway" >/dev/null 2>&1; then
  fail "Independent check failed: a runaway worker is still active."
fi

if pgrep -u "$(id -u)" -f "$INCIDENT_ROOT/bin/report-worker-child" >/dev/null 2>&1; then
  fail "Independent check failed: a rogue child process is still active."
fi
