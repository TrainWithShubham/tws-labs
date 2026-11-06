#!/bin/bash
set -euo pipefail

mkdir -p "$HOME/proc-incident/bin" "$HOME/proc-incident/config" "$HOME/proc-incident/run" "$HOME/proc-incident/reports"

# 1. Kill any existing instances
pkill -f "proc-incident/bin/spin-worker" 2>/dev/null || true
rm -f "$HOME/proc-incident/run/worker.pid" "$HOME/proc-incident/run/worker.status" "$HOME/proc-incident/reports/rogue-pid.txt"

# 2. Worker script
cat << 'WORKER_EOF' > "$HOME/proc-incident/bin/spin-worker"
#!/bin/bash
PID_FILE="$(dirname "$0")/../run/worker.pid"
STATUS_FILE="$(dirname "$0")/../run/worker.status"
echo "$$" > "$PID_FILE"

cleanup() {
  echo "CLEAN_SHUTDOWN" > "$STATUS_FILE"
  rm -f "$PID_FILE"
  exit 0
}
trap cleanup SIGTERM SIGINT

while true; do
  sleep 0.5
done
WORKER_EOF
chmod 0755 "$HOME/proc-incident/bin/spin-worker"

# 3. Spawn background worker
nohup "$HOME/proc-incident/bin/spin-worker" >/dev/null 2>&1 &
sleep 0.2

# 4. Bad configuration
cat << 'EOF' > "$HOME/proc-incident/config/worker.conf"
# Worker Operational Configuration
WORKER_NAME=spin-worker
SPIN_INTERVAL=0
MAX_ITERATIONS=-1
EOF
chmod 0644 "$HOME/proc-incident/config/worker.conf"

rm -f "$HOME/proc-incident/.service-audit.passed"

# 5. Verification tool
cat << 'VERIFY_EOF' > "$HOME/proc-incident/verify-service"
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# 1. Worker must not be running
if pgrep -f "proc-incident/bin/spin-worker" >/dev/null 2>&1; then
  echo "FAIL: spin-worker is still running. Terminate it with SIGTERM." >&2
  exit 1
fi

# 2. Clean shutdown must have occurred
if [ ! -f "run/worker.status" ] || ! grep -q "CLEAN_SHUTDOWN" run/worker.status; then
  echo "FAIL: run/worker.status does not report CLEAN_SHUTDOWN." >&2
  exit 1
fi

# 3. Config must have healthy limits
if ! grep -Eq "^SPIN_INTERVAL=5$" config/worker.conf; then
  echo "FAIL: config/worker.conf does not set SPIN_INTERVAL=5." >&2
  exit 1
fi

if ! grep -Eq "^MAX_ITERATIONS=100$" config/worker.conf; then
  echo "FAIL: config/worker.conf does not set MAX_ITERATIONS=100." >&2
  exit 1
fi

cat << 'MARKER_EOF' > ".service-audit.passed"
{
  "status": "PASSED",
  "verified_at": "2026-11-05T12:00:00Z",
  "audit": "process-service-fundamentals"
}
MARKER_EOF

echo "SUCCESS: Process lifecycle and service configuration verified."
exit 0
VERIFY_EOF
chmod 0755 "$HOME/proc-incident/verify-service"
