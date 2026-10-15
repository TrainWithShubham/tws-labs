#!/bin/bash
set -e

mkdir -p var/log config bin

# 1. Create and spawn a runaway-worker executable so /proc/<pid>/comm is "runaway-worker"
cat << 'EOF' > bin/runaway-worker
#!/bin/bash
while true; do sleep 1; done
EOF
chmod +x bin/runaway-worker

./bin/runaway-worker >/dev/null 2>&1 &
echo $! > .runaway.pid
disown

# 2. Create a simulated huge log file (50MB sparse file)
truncate -s 50M var/log/app-error.log

# 3. Create database configuration with insecure permissions (777)
cat << 'EOF' > config/database.env
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USER=appuser
DB_PASSWORD=supersecret_pass
EOF
chmod 777 config/database.env

# 4. Create the service startup script
cat << 'EOF' > start.sh
#!/bin/bash
set -e

# Pre-flight check 1: runaway worker must not be running
if [ -f .runaway.pid ]; then
  pid=$(cat .runaway.pid 2>/dev/null)
  if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
    echo "[ERROR] Pre-flight check failed: runaway-worker (PID $pid) is still active." >&2
    exit 1
  fi
fi

if pgrep -f runaway-worker >/dev/null 2>&1 || pgrep runaway-worker >/dev/null 2>&1; then
  echo "[ERROR] Pre-flight check failed: runaway-worker is still active." >&2
  exit 1
fi

# Pre-flight check 2: var/log/app-error.log must be truncated
if [ -f var/log/app-error.log ]; then
  size=$(stat -c %s var/log/app-error.log 2>/dev/null || stat -f %z var/log/app-error.log 2>/dev/null || echo 0)
  if [ "$size" -gt 1024 ]; then
    echo "[ERROR] Pre-flight check failed: var/log/app-error.log exceeds disk quota ($size bytes)." >&2
    exit 1
  fi
fi

# Pre-flight check 3: permissions on config/database.env must be 600
perms=$(stat -c %a config/database.env 2>/dev/null || stat -f %Lp config/database.env 2>/dev/null || echo "")
if [ "$perms" != "600" ]; then
  echo "[ERROR] Pre-flight check failed: config/database.env permissions must be 600 (currently $perms)." >&2
  exit 1
fi

echo "All pre-flight checks passed."
echo "Starting api-service in background..."
( exec -a api-service sleep 3600 ) >/dev/null 2>&1 &
echo $! > app.pid
disown
echo "api-service started successfully with PID $(cat app.pid)"
EOF
chmod +x start.sh
