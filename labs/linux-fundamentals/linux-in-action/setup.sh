#!/bin/bash
set -e

# Cleanup any previous stale processes before seeding sandbox
safe_cleanup_pid() {
  local pid_file="$1"
  local expected_comm="$2"
  [ -f "$pid_file" ] || return 0

  python3 -c '
import os, sys, signal, time, select

pid_file = sys.argv[1]
expected_comm = sys.argv[2][:15] # Linux TASK_COMM_LEN limit
grace_period = 1.0

def get_proc_stat(pid):
    try:
        proc_dir = f"/proc/{pid}"
        st = os.stat(proc_dir)
        uid = st.st_uid
        with open(f"{proc_dir}/comm", "r") as f:
            comm = f.read().strip()
        with open(f"{proc_dir}/stat", "r") as f:
            raw_stat = f.read()
        rparen = raw_stat.rfind(")")
        tail = raw_stat[rparen + 1:].strip().split()
        starttime = int(tail[19]) # Field 22 in /proc/<pid>/stat
        return uid, comm, starttime
    except (FileNotFoundError, ProcessLookupError, PermissionError, IndexError, ValueError):
        return None

if not os.path.isfile(pid_file):
    sys.exit(0)

# Strict PID file validation: EXACTLY two positive integers (<pid> <starttime>)
try:
    with open(pid_file, "r") as f:
        content = f.read()
    parts = content.strip().split()
    if len(parts) != 2:
        try:
            os.unlink(pid_file)
        except OSError:
            pass
        sys.exit(0)
    pid = int(parts[0])
    expected_start = int(parts[1])
    if pid <= 0 or expected_start <= 0:
        raise ValueError("Non-positive numeric values")
except Exception:
    try:
        os.unlink(pid_file)
    except OSError:
        pass
    sys.exit(0)

# Safe fallback check: pidfd support MUST be present; refuse all numeric signalling
if not hasattr(os, "pidfd_open") or not hasattr(signal, "pidfd_send_signal"):
    print(f"[WARN] pidfd support unavailable. Refusing numeric-PID signalling on {pid_file} to prevent PID-reuse races.", file=sys.stderr)
    sys.exit(0)

# Pre-validation before pidfd_open
pre_stat = get_proc_stat(pid)
if not pre_stat:
    try:
        os.unlink(pid_file)
    except OSError:
        pass
    sys.exit(0)

uid, comm, start_time = pre_stat
current_uid = os.getuid()

if uid != current_uid or comm != expected_comm or start_time != expected_start:
    sys.exit(0)

# Race-free acquisition via pidfd_open
try:
    pidfd = os.pidfd_open(pid, 0)
except OSError:
    sys.exit(0)

try:
    # Post-pidfd_open re-validation: confirm pinned process still matches exact identity
    post_stat = get_proc_stat(pid)
    if not post_stat:
        try:
            os.unlink(pid_file)
        except OSError:
            pass
        sys.exit(0)

    p_uid, p_comm, p_start = post_stat
    if p_uid != current_uid or p_comm != expected_comm or p_start != expected_start:
        sys.exit(0)

    # Graceful termination via pinned handle
    try:
        signal.pidfd_send_signal(pidfd, signal.SIGTERM)
    except ProcessLookupError:
        try:
            os.unlink(pid_file)
        except OSError:
            pass
        sys.exit(0)
    except OSError:
        sys.exit(0)

    # Bounded grace period polling (1.0 second)
    rlist, _, _ = select.select([pidfd], [], [], grace_period)
    if rlist:
        try:
            os.unlink(pid_file)
        except OSError:
            pass
        sys.exit(0)

    # Escalation to SIGKILL through the same pinned pidfd
    try:
        signal.pidfd_send_signal(pidfd, signal.SIGKILL)
        select.select([pidfd], [], [], 1.0)
    except (ProcessLookupError, OSError):
        pass

    try:
        os.unlink(pid_file)
    except OSError:
        pass
finally:
    os.close(pidfd)
' "$pid_file" "$expected_comm" 2>/dev/null || true
}

safe_cleanup_pid ".worker.pid" "payment-worker"
safe_cleanup_pid "payment.pid" "payment-service"
rm -f .service.lock

# Create directory hierarchy
mkdir -p logs reports config bin .fixtures

# Task 1 Fixture: web access log with realistic entries
cat << 'EOF' > .fixtures/service.log
2026-11-02T10:14:00Z 10.0.0.1 app-gw - GET https /api/v1/health HTTP/1.1 200 48
2026-11-02T10:14:02Z 10.0.0.2 app-gw - POST https /api/v1/charge HTTP/1.1 500 248
2026-11-02T10:14:05Z 10.0.0.3 app-gw - GET https /api/v1/users HTTP/1.1 200 1024
2026-11-02T10:14:10Z 10.0.0.4 app-gw - GET https /favicon.ico HTTP/1.1 404 120
2026-11-02T10:14:15Z 10.0.0.5 app-gw - POST https /api/v1/refund HTTP/1.1 500 312
2026-11-02T10:14:20Z 10.0.0.6 app-gw - POST https /api/v1/checkout HTTP/1.1 200 512
2026-11-02T10:14:25Z 10.0.0.7 app-gw - POST https /api/v1/payout HTTP/1.1 500 184
EOF
cp .fixtures/service.log logs/service.log

# Task 2 Fixture: configuration template
cat << 'EOF' > .fixtures/app.template
# Application configuration template
PORT=80
HOST=127.0.0.1
LOG_LEVEL=INFO
WORKERS=2
TOKEN_FILE=config/auth.token
EOF
cp .fixtures/app.template config/app.template

# Task 3 Fixture: sensitive authentication token with loose permissions (644)
cat << 'EOF' > config/auth.token
sec_tok_prod_99f82d11b3e7a04c
EOF
chmod 644 config/auth.token

# Task 4 Fixture: staged rogue payment-worker
cat << 'EOF' > bin/payment-worker
#!/bin/bash
while true; do sleep 1; done
EOF
chmod +x bin/payment-worker

# Spawn payment-worker and persist strict launch-time identity
./bin/payment-worker >/dev/null 2>&1 &
worker_pid=$!
raw_stat=$(cat "/proc/$worker_pid/stat" 2>/dev/null || true)
start_tick=$(echo "${raw_stat##*) }" | awk '{print $20}')
echo "$worker_pid $start_tick" > .worker.pid
touch .service.lock
disown

# Task 5 Fixture: empty configuration test fixture
touch .fixtures/empty.env

# Task 6 Fixtures: daemon executable and start.sh orchestration script
cat << 'EOF' > bin/payment-service
#!/bin/bash
while true; do sleep 1; done
EOF
chmod +x bin/payment-service

cat << 'EOF' > start.sh
#!/bin/bash
set -e

# Pre-flight check 1: payment-worker must not be active
if [ -f .worker.pid ]; then
  read -r wpid wtick wextra < .worker.pid 2>/dev/null || true
  if [ -n "$wpid" ] && [ -n "$wtick" ] && [ -z "$wextra" ] &&
     [ "$wpid" -eq "$wpid" ] 2>/dev/null && [ "$wpid" -gt 0 ] 2>/dev/null &&
     [ "$wtick" -eq "$wtick" ] 2>/dev/null && [ "$wtick" -gt 0 ] 2>/dev/null; then
    if [ -d "/proc/$wpid" ]; then
      wcomm=$(cat "/proc/$wpid/comm" 2>/dev/null || true)
      wstat=$(cat "/proc/$wpid/stat" 2>/dev/null || true)
      actual_tick=$(echo "${wstat##*) }" | awk '{print $20}')
      if [ "$wcomm" = "payment-worker" ] && [ "$actual_tick" = "$wtick" ]; then
        echo "[ERROR] Pre-flight check failed: payment-worker is still active." >&2
        exit 1
      fi
    fi
  fi
fi

# Pre-flight check 2: stale lockfile must be removed
if [ -e .service.lock ]; then
  echo "[ERROR] Pre-flight check failed: stale lockfile .service.lock exists." >&2
  exit 1
fi

# Pre-flight check 3: validate config using check-service
if [ ! -x bin/check-service ]; then
  echo "[ERROR] Pre-flight check failed: bin/check-service is missing or not executable." >&2
  exit 1
fi

if ! bin/check-service config/app.env >/dev/null 2>&1; then
  echo "[ERROR] Pre-flight check failed: config/app.env validation failed." >&2
  exit 1
fi

# Pre-flight check 4: token permissions must be 600
token_perms=$(stat -c %a config/auth.token 2>/dev/null || stat -f %Lp config/auth.token 2>/dev/null || true)
if [ "$token_perms" != "600" ]; then
  echo "[ERROR] Pre-flight check failed: config/auth.token permissions must be 600 (currently $token_perms)." >&2
  exit 1
fi

echo "All pre-flight checks passed."
echo "Starting payment-service daemon..."
./bin/payment-service >/dev/null 2>&1 &
service_pid=$!
raw_stat=$(cat "/proc/$service_pid/stat" 2>/dev/null || true)
start_tick=$(echo "${raw_stat##*) }" | awk '{print $20}')
echo "$service_pid $start_tick" > payment.pid
disown
echo "payment-service started successfully with PID $service_pid (tick $start_tick)"
EOF
chmod +x start.sh
