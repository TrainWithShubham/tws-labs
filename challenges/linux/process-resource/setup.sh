#!/bin/bash
set -euo pipefail

# 1. Base Resolution Decision Sequence
SELECTED_BASE=""
if [ -n "${LAB_HOME:-}" ] && [ -d "$LAB_HOME" ]; then
  SELECTED_BASE="$LAB_HOME"
elif [ -n "${HOME:-}" ] && [ -d "$HOME" ]; then
  SELECTED_BASE="$HOME"
else
  echo "Fatal: Neither LAB_HOME nor HOME points to a valid existing directory." >&2
  exit 1
fi

CANONICAL_BASE="$(realpath -e "$SELECTED_BASE" 2>/dev/null)" || {
  echo "Fatal: Failed to resolve canonical base directory for: $SELECTED_BASE" >&2
  exit 1
}

case "$CANONICAL_BASE" in
  /|/home|/root|/tmp|/var|/usr|/bin|/etc)
    echo "Fatal: Base directory cannot be a top-level system mount: $CANONICAL_BASE" >&2
    exit 1
    ;;
esac

# 2. Lifecycle Pre-Creation Safety Validation
INTENDED_ROOT="$CANONICAL_BASE/incident"

if [ -e "$INTENDED_ROOT" ]; then
  if [ -L "$INTENDED_ROOT" ]; then
    echo "Fatal: $INTENDED_ROOT is a symlink. Refusing to operate on symlinked challenge root." >&2
    exit 1
  fi
  if [ ! -d "$INTENDED_ROOT" ]; then
    echo "Fatal: $INTENDED_ROOT exists but is not a directory." >&2
    exit 1
  fi
else
  if [ ! -w "$CANONICAL_BASE" ]; then
    echo "Fatal: Base directory $CANONICAL_BASE is not writable." >&2
    exit 1
  fi
  mkdir -m 0755 "$INTENDED_ROOT"
fi

INCIDENT_ROOT="$(realpath -e "$INTENDED_ROOT" 2>/dev/null)" || {
  echo "Fatal: Failed to canonically resolve $INTENDED_ROOT." >&2
  exit 1
}

if [ "$(dirname "$INCIDENT_ROOT")" != "$CANONICAL_BASE" ] || [ "$(basename "$INCIDENT_ROOT")" != "incident" ]; then
  echo "Fatal: INCIDENT_ROOT ($INCIDENT_ROOT) fails boundary verification." >&2
  exit 1
fi

# 3. Process Cleanup & Idempotency Guards
# Safely terminate any prior challenge processes belonging to this user
safe_terminate_pid() {
  local pid="$1"
  local expected_bin="$2"
  local expected_arg="${3:-}"

  # 1. Validate numeric PID > 1
  if ! [[ "$pid" =~ ^[0-9]+$ ]] || [ "$pid" -le 1 ] 2>/dev/null; then
    return 0
  fi

  # 2. Check process existence
  if ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  # 3. Proc entry existence
  if [ ! -d "/proc/$pid" ]; then
    return 0
  fi

  # 4. User ownership check (must match current UID)
  local proc_uid=""
  [ -r "/proc/$pid/status" ] && proc_uid="$(awk '/^Uid:/ {print $2}' "/proc/$pid/status" 2>/dev/null || echo "")"
  [ -z "$proc_uid" ] && [ -d "/proc/$pid" ] && proc_uid="$(stat -c %u "/proc/$pid" 2>/dev/null || echo "")"
  if [ "$proc_uid" != "$(id -u)" ]; then
    return 1
  fi

  # 5. Executable / command line verification
  local proc_cmd=""
  [ -r "/proc/$pid/cmdline" ] && proc_cmd="$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || echo "")"
  [ -z "$proc_cmd" ] && proc_cmd="$(ps -p "$pid" -o cmd= 2>/dev/null || echo "")"
  if [ -z "$proc_cmd" ]; then
    return 1
  fi

  if ! echo "$proc_cmd" | grep -F -q "$expected_bin"; then
    return 1
  fi

  if [ -n "$expected_arg" ]; then
    if ! echo "$proc_cmd" | grep -F -q -e "$expected_arg"; then
      return 1
    fi
  fi

  # 6. Revalidate immediately before signaling
  if [ ! -d "/proc/$pid" ]; then
    return 0
  fi
  local check_cmd
  check_cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || echo "")"
  if ! echo "$check_cmd" | grep -F -q "$expected_bin"; then
    return 1
  fi

  # 7. Attempt polite termination with SIGTERM (trappable by target)
  kill -TERM "$pid" 2>/dev/null || true
  for _ in $(seq 1 20); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 0.05
  done

  # 8. Escalate to SIGKILL if still active
  # Note: SIGKILL cannot be caught or trapped by any userland process;
  # the Linux kernel unconditionally terminates the process immediately.
  if kill -0 "$pid" 2>/dev/null; then
    if [ -d "/proc/$pid" ]; then
      local recheck_cmd
      recheck_cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || echo "")"
      if echo "$recheck_cmd" | grep -F -q "$expected_bin"; then
        kill -KILL "$pid" 2>/dev/null || true
      fi
    fi
  fi

  # 9. Wait and verify process is gone
  for _ in $(seq 1 10); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 0.05
  done

  return 0
}

cleanup_incident_processes() {
  local root="$1"

  # Pass 1: Terminate via recorded PID files with strict role validation
  if [ -d "$root/run" ]; then
    for pid_file in "$root/run"/*.pid; do
      [ -f "$pid_file" ] || continue
      local pid
      pid="$(cat "$pid_file" 2>/dev/null || echo "")"
      local fname
      fname="$(basename "$pid_file")"
      local exp_bin="" exp_arg=""
      case "$fname" in
        rogue-child.pid)
          exp_bin="$root/bin/report-worker-child"
          ;;
        rogue-worker.pid)
          exp_bin="$root/bin/report-worker"
          exp_arg="--mode=runaway"
          ;;
        metrics-worker.pid)
          exp_bin="$root/bin/report-worker"
          exp_arg="--queue=metrics"
          ;;
        report-worker.pid)
          exp_bin="$root/bin/report-worker"
          ;;
        supervisor.pid)
          exp_bin="$root/bin/report-supervisor"
          ;;
      esac
      if [ -n "$exp_bin" ]; then
        safe_terminate_pid "$pid" "$exp_bin" "$exp_arg" || true
      fi
      rm -f "$pid_file"
    done
  fi

  # Pass 2: Clean up any orphaned or unrecorded challenge-owned processes
  # Candidate discovery strictly scoped to current UID and $root/bin/report-
  local candidates
  candidates="$(pgrep -u "$(id -u)" -f "$root/bin/report-" 2>/dev/null || true)"
  for p in $candidates; do
    [ -n "$p" ] || continue
    for target_bin in report-worker-child report-worker report-supervisor; do
      if safe_terminate_pid "$p" "$root/bin/$target_bin" ""; then
        break
      fi
    done
  done
}

cleanup_incident_processes "$INCIDENT_ROOT"

# 4. Provision Directory Structure
for sub in bin config run reports var var/log; do
  TARGET_PATH="$INCIDENT_ROOT/$sub"
  if [ -L "$TARGET_PATH" ]; then
    echo "Fatal: Subdirectory $TARGET_PATH is an unexpected symlink. Aborting." >&2
    exit 1
  fi
done

rm -rf "$INCIDENT_ROOT/run" "$INCIDENT_ROOT/reports" "$INCIDENT_ROOT/var"
mkdir -p "$INCIDENT_ROOT/bin" "$INCIDENT_ROOT/config" "$INCIDENT_ROOT/run" "$INCIDENT_ROOT/reports" "$INCIDENT_ROOT/var/log"
chmod 0755 "$INCIDENT_ROOT/bin" "$INCIDENT_ROOT/config" "$INCIDENT_ROOT/run" "$INCIDENT_ROOT/reports" "$INCIDENT_ROOT/var/log"

# 5. Provision Executable Binaries
cat << 'WORKER_CHILD_EOF' > "$INCIDENT_ROOT/bin/report-worker-child"
#!/bin/bash
# Sub-worker child process spawned by runaway batch worker
trap "exit 0" TERM INT QUIT
COUNT=0
while [ "$COUNT" -lt 600 ]; do
  sleep 1 &
  wait $! 2>/dev/null || exit 0
  COUNT=$((COUNT + 1))
done
WORKER_CHILD_EOF
chmod 0755 "$INCIDENT_ROOT/bin/report-worker-child"

cat << 'WORKER_EOF' > "$INCIDENT_ROOT/bin/report-worker"
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"

CHILD_PID=""

cleanup_child() {
  if [ -n "$CHILD_PID" ] && [ "$CHILD_PID" -gt 1 ] 2>/dev/null; then
    if kill -0 "$CHILD_PID" 2>/dev/null && [ -d "/proc/$CHILD_PID" ]; then
      local c_uid="" c_cmd=""
      [ -r "/proc/$CHILD_PID/status" ] && c_uid="$(awk '/^Uid:/ {print $2}' "/proc/$CHILD_PID/status" 2>/dev/null || echo "")"
      [ -z "$c_uid" ] && [ -d "/proc/$CHILD_PID" ] && c_uid="$(stat -c %u "/proc/$CHILD_PID" 2>/dev/null || echo "")"
      [ -r "/proc/$CHILD_PID/cmdline" ] && c_cmd="$(cat "/proc/$CHILD_PID/cmdline" 2>/dev/null | tr '\0' ' ' || echo "")"
      [ -z "$c_cmd" ] && c_cmd="$(ps -p "$CHILD_PID" -o cmd= 2>/dev/null || echo "")"
      if [ "$c_uid" = "$(id -u)" ] && echo "$c_cmd" | grep -F -q "$DIR/report-worker-child"; then
        kill -TERM "$CHILD_PID" 2>/dev/null || true
        for _ in $(seq 1 10); do
          if ! kill -0 "$CHILD_PID" 2>/dev/null; then break; fi
          sleep 0.05
        done
        if kill -0 "$CHILD_PID" 2>/dev/null; then
          kill -KILL "$CHILD_PID" 2>/dev/null || true
        fi
      fi
    fi
  fi
}

trap "cleanup_child; exit 0" TERM INT QUIT
trap cleanup_child EXIT

MODE="standard"
QUEUE=""
BATCH=""
START_DAEMON=0
CONCURRENCY=2

for arg in "$@"; do
  case "$arg" in
    --mode=*) MODE="${arg#*=}" ;;
    --queue=*) QUEUE="${arg#*=}" ;;
    --batch-id=*) BATCH="${arg#*=}" ;;
    --concurrency=*) CONCURRENCY="${arg#*=}" ;;
    --start) START_DAEMON=1 ;;
  esac
done

if [ "$START_DAEMON" -eq 1 ]; then
  if [ -f "$ROOT/config/worker.env" ]; then
    CONF_MODE="$(awk -F= '/^[[:space:]]*WORKER_MODE=/ {gsub(/^[[:space:]]+|[[:space:]]+$|"/, "", $2); print $2}' "$ROOT/config/worker.env")"
    CONF_CONC="$(awk -F= '/^[[:space:]]*BATCH_CONCURRENCY=/ {gsub(/^[[:space:]]+|[[:space:]]+$|"/, "", $2); print $2}' "$ROOT/config/worker.env")"
    [ -n "$CONF_MODE" ] && MODE="$CONF_MODE"
    [ -n "$CONF_CONC" ] && CONCURRENCY="$CONF_CONC"
  fi

  if [ "$MODE" = "runaway" ]; then
    echo "[ERROR] Refusing to start worker in runaway mode. Fix config/worker.env first." >&2
    exit 1
  fi

  nohup "$0" --queue="${QUEUE:-reports}" --mode="$MODE" --concurrency="$CONCURRENCY" > "$ROOT/var/log/worker.log" 2>&1 < /dev/null &
  NEW_PID=$!
  echo "$NEW_PID" > "$ROOT/run/report-worker.pid"
  echo "[OK] Started report-worker [PID $NEW_PID] (queue=${QUEUE:-reports}, mode=$MODE, concurrency=$CONCURRENCY)"
  exit 0
fi

if [ "$MODE" = "runaway" ]; then
  "$DIR/report-worker-child" --parent-batch="${BATCH:-9021}" --parent-pid=$$ &
  CHILD_PID=$!
  echo "$CHILD_PID" > "$ROOT/run/rogue-child.pid"
fi

COUNT=0
while [ "$COUNT" -lt 600 ]; do
  sleep 1 &
  wait $! 2>/dev/null || exit 0
  COUNT=$((COUNT + 1))
done
WORKER_EOF
chmod 0755 "$INCIDENT_ROOT/bin/report-worker"

cat << 'SUPERVISOR_EOF' > "$INCIDENT_ROOT/bin/report-supervisor"
#!/bin/bash
trap "exit 0" TERM INT QUIT
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"

echo $$ > "$ROOT/run/supervisor.pid"

"$DIR/report-worker" --queue=metrics --concurrency=2 &
echo $! > "$ROOT/run/metrics-worker.pid"

"$DIR/report-worker" --queue=reports --mode=runaway --batch-id=9021 &
echo $! > "$ROOT/run/rogue-worker.pid"

COUNT=0
while [ "$COUNT" -lt 600 ]; do
  sleep 1 &
  wait $! 2>/dev/null || exit 0
  COUNT=$((COUNT + 1))
done
SUPERVISOR_EOF
chmod 0755 "$INCIDENT_ROOT/bin/report-supervisor"

cat << 'AUDIT_EOF' > "$INCIDENT_ROOT/bin/audit-processes"
#!/bin/bash
set -u

fail() {
  echo "[AUDIT FAILED] $*" >&2
  exit 1
}

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"

# 1. Supervisor check
[ -f "$ROOT/run/supervisor.pid" ] || fail "Supervisor PID file missing (run/supervisor.pid)."
SUPER_PID="$(cat "$ROOT/run/supervisor.pid" 2>/dev/null || echo "")"
[ -n "$SUPER_PID" ] || fail "Supervisor PID file is empty."
kill -0 "$SUPER_PID" 2>/dev/null || fail "Supervisor process (PID $SUPER_PID) is not running."
ps -p "$SUPER_PID" -o cmd= 2>/dev/null | grep -q "report-supervisor" || fail "Supervisor process PID $SUPER_PID command signature mismatch."

# 2. Metrics worker check
[ -f "$ROOT/run/metrics-worker.pid" ] || fail "Metrics worker PID file missing (run/metrics-worker.pid)."
METRICS_PID="$(cat "$ROOT/run/metrics-worker.pid" 2>/dev/null || echo "")"
[ -n "$METRICS_PID" ] || fail "Metrics worker PID file is empty."
kill -0 "$METRICS_PID" 2>/dev/null || fail "Metrics worker process (PID $METRICS_PID) is not running."
ps -p "$METRICS_PID" -o cmd= 2>/dev/null | grep -q -- "--queue=metrics" || fail "Metrics worker PID $METRICS_PID is not running with --queue=metrics."

# 3. Rogue worker checks
if [ -f "$ROOT/run/rogue-worker.pid" ]; then
  ROGUE_PID="$(cat "$ROOT/run/rogue-worker.pid" 2>/dev/null || echo "")"
  if [ -n "$ROGUE_PID" ] && kill -0 "$ROGUE_PID" 2>/dev/null; then
    if [ -d "/proc/$ROGUE_PID" ]; then
      proc_cmd="$(tr '\0' ' ' < "/proc/$ROGUE_PID/cmdline" 2>/dev/null || ps -p "$ROGUE_PID" -o cmd= 2>/dev/null || echo "")"
      if echo "$proc_cmd" | grep -F -q "$ROOT/bin/report-worker" && echo "$proc_cmd" | grep -F -q -- "--mode=runaway"; then
        fail "Rogue worker (PID $ROGUE_PID) is still running. Terminate it before auditing."
      fi
    fi
  fi
fi

if pgrep -u "$(id -u)" -f "$ROOT/bin/report-worker.*--mode=runaway" >/dev/null 2>&1; then
  fail "A report-worker with --mode=runaway is still active on this node."
fi

if pgrep -u "$(id -u)" -f "$ROOT/bin/report-worker-child" >/dev/null 2>&1; then
  fail "A report-worker-child process is still active on this node."
fi

# 4. Configuration check
CONF="$ROOT/config/worker.env"
[ -f "$CONF" ] || fail "Configuration file config/worker.env missing."

CONF_MODE="$(awk -F= '/^[[:space:]]*WORKER_MODE=/ {gsub(/^[[:space:]]+|[[:space:]]+$|"/, "", $2); print $2}' "$CONF")"
CONF_CONC="$(awk -F= '/^[[:space:]]*BATCH_CONCURRENCY=/ {gsub(/^[[:space:]]+|[[:space:]]+$|"/, "", $2); print $2}' "$CONF")"
CONF_MEM="$(awk -F= '/^[[:space:]]*MAX_MEMORY_MB=/ {gsub(/^[[:space:]]+|[[:space:]]+$|"/, "", $2); print $2}' "$CONF")"

[ "$CONF_MODE" = "standard" ] || fail "config/worker.env WORKER_MODE must be 'standard' (found: '$CONF_MODE')."
[ "$CONF_CONC" = "2" ] || fail "config/worker.env BATCH_CONCURRENCY must be '2' (found: '$CONF_CONC')."
[ "$CONF_MEM" = "512" ] || fail "config/worker.env MAX_MEMORY_MB must be '512' (found: '$CONF_MEM')."

# 5. Clean report-worker check
[ -f "$ROOT/run/report-worker.pid" ] || fail "Clean reporting worker not found. Start it with: ./bin/report-worker --queue=reports --start"
WORKER_PID="$(cat "$ROOT/run/report-worker.pid" 2>/dev/null || echo "")"
[ -n "$WORKER_PID" ] || fail "run/report-worker.pid is empty."
kill -0 "$WORKER_PID" 2>/dev/null || fail "Clean report-worker (PID $WORKER_PID) is not running."
WORKER_CMD="$(ps -p "$WORKER_PID" -o cmd= 2>/dev/null || echo "")"
echo "$WORKER_CMD" | grep -q -- "--queue=reports" || fail "Reporting worker PID $WORKER_PID is not listening on queue 'reports'."
echo "$WORKER_CMD" | grep -q -- "--mode=standard" || fail "Reporting worker PID $WORKER_PID is not running with --mode=standard."

# 6. Generate audit-success.marker
cat << 'MARKER_EOF' > "$ROOT/reports/audit-success.marker"
PROCESS_INCIDENT=RESOLVED
ROGUE_WORKERS=NONE
SUPERVISOR_STATUS=HEALTHY
METRICS_WORKER=ACTIVE
REPORT_WORKER=ACTIVE
CONFIG_INTEGRITY=VERIFIED
AUDITED_BY=process_audit_v1
MARKER_EOF

echo "[AUDIT OK] All process monitors healthy. Generated reports/audit-success.marker."
AUDIT_EOF
chmod 0755 "$INCIDENT_ROOT/bin/audit-processes"

# 6. Provision Initial Configuration and Status
cat << 'CONF_EOF' > "$INCIDENT_ROOT/config/worker.env"
# Worker runtime configuration
WORKER_MODE=runaway
BATCH_CONCURRENCY=16
MAX_MEMORY_MB=2048
LOG_LEVEL=DEBUG
CONF_EOF

cat << 'STATUS_EOF' > "$INCIDENT_ROOT/reports/incident.status"
[INCIDENT TELEMETRY] 2026-11-05T08:30:00Z
STATUS: CRITICAL_RESOURCE_PRESSURE (SIMULATED)
NOTE: This is a controlled process-management simulation. Worker processes intentionally
consume negligible CPU and memory (using idle sleep intervals); the exercise creates
no host CPU or memory exhaustion. The incident scenario is represented logically through
process names, arguments, environment configuration, and parent-child hierarchy.
Learners practise process inspection, tree analysis, safe termination, configuration
remediation, and recovery verification.
SUPERVISOR: ACTIVE (run/supervisor.pid)
HEALTHY_WORKERS: metrics-worker (run/metrics-worker.pid)
ROGUE_WORKER: report-worker running on queue 'reports' with --mode=runaway
ROGUE_BATCH_ID: 9021
SYMPTOMS: Unthrottled loop execution, unmanaged child tasks, queue starvation.
ACTIONS:
  1. Inspect process table and identify ROGUE_PID, PARENT_PID, ROGUE_QUEUE.
  2. Inspect hierarchy and identify CHILD_PID, BATCH_ID, WORKER_NAME.
  3. Safely terminate rogue worker and child without terminating siblings or supervisor.
  4. Fix config/worker.env, start clean report-worker, and run bin/audit-processes.
STATUS_EOF

# 7. Spawn Process Hierarchy
"$INCIDENT_ROOT/bin/report-supervisor" &
SUP_PID=$!
disown "$SUP_PID" 2>/dev/null || true

for _ in $(seq 1 20); do
  if [ -s "$INCIDENT_ROOT/run/rogue-child.pid" ]; then
    break
  fi
  sleep 0.05
done

if [ ! -s "$INCIDENT_ROOT/run/rogue-child.pid" ]; then
  echo "Fatal: Timeout waiting for rogue process tree initialization." >&2
  exit 1
fi

echo "Process incident environment provisioned successfully."
