#!/bin/bash
mkdir -p config bin .fixtures

# Reuse safe_cleanup_pid helper to ensure race-free, pidfd-only termination
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

# Clean up stale worker via race-free pidfd lifecycle
safe_cleanup_pid ".worker.pid" "payment-worker"
rm -f .service.lock

# Ensure config/app.env is ready
if [ ! -f config/app.template ]; then
  cat << 'EOF' > config/app.template
# Application configuration template
PORT=80
HOST=127.0.0.1
LOG_LEVEL=INFO
WORKERS=2
TOKEN_FILE=config/auth.token
EOF
fi
[ -f config/app.env ] || sed 's/PORT=80/PORT=8080/' config/app.template > config/app.env

# Ensure token permissions
[ -f config/auth.token ] || echo "sec_tok_prod_99f82d11b3e7a04c" > config/auth.token
chmod 600 config/auth.token

# Ensure bin/check-service is present and executable
if [ ! -x bin/check-service ]; then
  printf '%s\n' '#!/bin/bash' \
    'validate() {' \
    '  if [ "$#" -ne 1 ]; then echo "Usage: check-service <config>" >&2; exit 1; fi' \
    '  if [ ! -e "$1" ] || [ ! -s "$1" ]; then echo "CONFIG ERROR"; echo "Error: file missing or empty" >&2; exit 2; fi' \
    '  echo "CONFIG OK"' \
    '  exit 0' \
    '}' \
    'validate "$@"' > bin/check-service
  chmod +x bin/check-service
fi
