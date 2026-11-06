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

# 3. Subdirectory Symlink Validation & Destructive-Operation Guards
for sub in var var/cache var/log reports config bin; do
  TARGET_PATH="$INCIDENT_ROOT/$sub"
  if [ -L "$TARGET_PATH" ]; then
    echo "Fatal: Subdirectory $TARGET_PATH is an unexpected symlink. Aborting." >&2
    exit 1
  fi
done

# Selective cleanup of challenge-owned leaf directories
rm -rf "$INCIDENT_ROOT/var/cache" "$INCIDENT_ROOT/var/log" "$INCIDENT_ROOT/reports"
mkdir -p "$INCIDENT_ROOT/bin" "$INCIDENT_ROOT/config" "$INCIDENT_ROOT/var/cache" "$INCIDENT_ROOT/var/log" "$INCIDENT_ROOT/reports"
chmod 0755 "$INCIDENT_ROOT/var/cache" "$INCIDENT_ROOT/var/log" "$INCIDENT_ROOT/reports"

# 4. Provision Task 1 Inodes: 2,500 temporary cache spool files
echo "Provisioning cache spool files..."
for i in $(seq -w 1 2500); do
  : > "$INCIDENT_ROOT/var/cache/sess_${i}.tmp"
done

# 5. Provision Task 2 & 3 Block Spew: ~25 MB active log with repeated error signatures
echo "Generating runaway log spew..."
cat << 'LOG_BLOCK' > "$INCIDENT_ROOT/var/log/app.log.block"
[2026-11-04T04:14:50.001Z] [INFO] Starting telemetry dispatch cycle #91024
[2026-11-04T04:14:50.005Z] [DEBUG] Dialing downstream connection endpoint postgres-primary:5432...
[2026-11-04T04:14:52.010Z] [ERROR] ConnectionRefused: downstream endpoint postgres-primary:5432 timed out (retry_loop=1, cause=DOWNSTREAM_TIMEOUT)
[2026-11-04T04:14:52.012Z] [DEBUG] Backoff retry scheduled in 100ms
[2026-11-04T04:14:52.115Z] [ERROR] ConnectionRefused: downstream endpoint postgres-primary:5432 timed out (retry_loop=2, cause=DOWNSTREAM_TIMEOUT)
[2026-11-04T04:14:52.120Z] [FATAL] Transaction batch failed: downstream database unavailable.
LOG_BLOCK

# Repeat block exponentially to reach ~25 MB efficiently
cat "$INCIDENT_ROOT/var/log/app.log.block" "$INCIDENT_ROOT/var/log/app.log.block" "$INCIDENT_ROOT/var/log/app.log.block" "$INCIDENT_ROOT/var/log/app.log.block" "$INCIDENT_ROOT/var/log/app.log.block" > "$INCIDENT_ROOT/var/log/app.log.tmp"
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13; do
  cat "$INCIDENT_ROOT/var/log/app.log.tmp" "$INCIDENT_ROOT/var/log/app.log.tmp" > "$INCIDENT_ROOT/var/log/app.log.next"
  mv -f "$INCIDENT_ROOT/var/log/app.log.next" "$INCIDENT_ROOT/var/log/app.log.tmp"
done
mv -f "$INCIDENT_ROOT/var/log/app.log.tmp" "$INCIDENT_ROOT/var/log/app.log"
rm -f "$INCIDENT_ROOT/var/log/app.log.block"
chmod 0644 "$INCIDENT_ROOT/var/log/app.log"

# 6. Provision Service Configuration
cat << 'EOF' > "$INCIDENT_ROOT/config/service.conf"
# Ingest Service Runtime Configuration
SERVICE_NAME=tx-collector
LOG_LEVEL=TRACE
PORT=9090
EOF
chmod 0644 "$INCIDENT_ROOT/config/service.conf"

# 7. Provision Unconfigured Logrotate Skeleton with Portability Check
CANONICAL_LOG="$(realpath -m "$INCIDENT_ROOT/var/log/app.log")"
if ! [[ "$CANONICAL_LOG" =~ ^[A-Za-z0-9_./-]+$ ]]; then
  echo "Fatal: Active log path '$CANONICAL_LOG' contains unsupported special characters." >&2
  exit 1
fi

cat << EOF > "$INCIDENT_ROOT/config/logrotate.conf"
"$CANONICAL_LOG" {
    # Unconfigured log rotation policy
    # Required: size 10M, rotate 5, compress, missingok, notifempty
}
EOF
chmod 0644 "$INCIDENT_ROOT/config/logrotate.conf"

# 8. Provision Incident Status Snapshot
cat << 'EOF' > "$INCIDENT_ROOT/reports/incident.status"
INCIDENT_ID=INC-8042
TIMESTAMP=2026-11-04T04:15:00Z
STATUS=CRITICAL_STORAGE_PRESSURE
ERROR_CODE=ENOSPC
MESSAGE="No space left on device: spool inode quota breached or log volume saturated."
EOF
chmod 0644 "$INCIDENT_ROOT/reports/incident.status"

# 9. Provision Deterministic Storage Auditor Tool
cat << 'AUDITOR_EOF' > "$INCIDENT_ROOT/bin/storage-audit"
#!/bin/bash
set -euo pipefail

AUDITOR_DIR="$(dirname "$(realpath -e "$0")")"
INCIDENT_DIR="$(dirname "$AUDITOR_DIR")"

echo "Running Storage Recovery Audit on $INCIDENT_DIR..."

# 1. Check cache inode count
CACHE_COUNT=$(find "$INCIDENT_DIR/var/cache" -maxdepth 1 -type f 2>/dev/null | wc -l)
if [ "$CACHE_COUNT" -gt 50 ]; then
  echo "Error: var/cache contains $CACHE_COUNT files (threshold is <= 50)." >&2
  exit 1
fi

# 2. Check active log size
ACTIVE_LOG="$INCIDENT_DIR/var/log/app.log"
if [ ! -f "$ACTIVE_LOG" ]; then
  echo "Error: Active log $ACTIVE_LOG is missing." >&2
  exit 2
fi
ACTIVE_SIZE=$(wc -c < "$ACTIVE_LOG")
if [ "$ACTIVE_SIZE" -gt 1024 ]; then
  echo "Error: Active log size is $ACTIVE_SIZE bytes (threshold is <= 1024 bytes)." >&2
  exit 2
fi

# 3. Check historical archive
ARCHIVE_LOG="$INCIDENT_DIR/var/log/app.log.1.gz"
if [ ! -f "$ARCHIVE_LOG" ]; then
  echo "Error: Historical archive $ARCHIVE_LOG is missing." >&2
  exit 3
fi
if ! gzip -t "$ARCHIVE_LOG" 2>/dev/null; then
  echo "Error: Historical archive $ARCHIVE_LOG is corrupt or not a valid gzip file." >&2
  exit 3
fi
ARCHIVE_SIZE=$(wc -c < "$ARCHIVE_LOG")
if [ "$ARCHIVE_SIZE" -lt 1000 ]; then
  echo "Error: Historical archive $ARCHIVE_LOG is empty or truncated." >&2
  exit 3
fi

# 4. Check total var/log directory size (<= 10MB)
LOG_DIR_KB=$(du -sk "$INCIDENT_DIR/var/log" 2>/dev/null | awk '{print $1}')
if [ "$LOG_DIR_KB" -gt 10240 ]; then
  echo "Error: var/log directory occupies ${LOG_DIR_KB}KB (threshold is <= 10240KB)." >&2
  exit 4
fi

# 5. Check service configuration
SERVICE_CONF="$INCIDENT_DIR/config/service.conf"
if [ ! -f "$SERVICE_CONF" ]; then
  echo "Error: $SERVICE_CONF is missing." >&2
  exit 5
fi
if ! grep -Eq "^[[:space:]]*LOG_LEVEL=WARN([[:space:]]|$)" "$SERVICE_CONF"; then
  echo "Error: config/service.conf does not set LOG_LEVEL=WARN." >&2
  exit 5
fi

# 6. Check logrotate configuration
LOGROTATE_CONF="$INCIDENT_DIR/config/logrotate.conf"
if [ ! -f "$LOGROTATE_CONF" ]; then
  echo "Error: $LOGROTATE_CONF is missing." >&2
  exit 6
fi

RAW_CONF_LOG=$(awk '/^[[:space:]]*[^#[:space:]]/ {gsub(/\"/, ""); print $1; exit}' "$LOGROTATE_CONF")
if [ -z "$RAW_CONF_LOG" ]; then
  echo "Error: config/logrotate.conf does not define a valid log target path." >&2
  exit 6
fi
RESOLVED_CONF_LOG=$(realpath -m "$RAW_CONF_LOG" 2>/dev/null || echo "")
ACTUAL_LOG=$(realpath -e "$ACTIVE_LOG")
if [ "$RESOLVED_CONF_LOG" != "$ACTUAL_LOG" ]; then
  echo "Error: config/logrotate.conf must target $ACTUAL_LOG (found $RAW_CONF_LOG)." >&2
  exit 6
fi

if ! grep -Eq "^[[:space:]]*size[[:space:]]+10M([[:space:]]|$)" "$LOGROTATE_CONF"; then
  echo "Error: config/logrotate.conf missing 'size 10M' directive." >&2
  exit 6
fi
if ! grep -Eq "^[[:space:]]*rotate[[:space:]]+5([[:space:]]|$)" "$LOGROTATE_CONF"; then
  echo "Error: config/logrotate.conf missing 'rotate 5' directive." >&2
  exit 6
fi
if ! grep -Eq "^[[:space:]]*compress([[:space:]]|$)" "$LOGROTATE_CONF"; then
  echo "Error: config/logrotate.conf missing 'compress' directive." >&2
  exit 6
fi
if ! grep -Eq "^[[:space:]]*missingok([[:space:]]|$)" "$LOGROTATE_CONF"; then
  echo "Error: config/logrotate.conf missing 'missingok' directive." >&2
  exit 6
fi
if ! grep -Eq "^[[:space:]]*notifempty([[:space:]]|$)" "$LOGROTATE_CONF"; then
  echo "Error: config/logrotate.conf missing 'notifempty' directive." >&2
  exit 6
fi

# 7. Atomic Marker Creation
MARKER_FILE="$INCIDENT_DIR/reports/audit-success.marker"
TMP_MARKER="$INCIDENT_DIR/reports/audit-success.marker.tmp.$$"
cat << 'MARKER_EOF' > "$TMP_MARKER"
STORAGE_PRESSURE=RESOLVED
BLOCK_USAGE_MB=OK
INODE_COUNT=OK
RETENTION_POLICY=COMPLIANT
ROTATION_CONFIG=VERIFIED
AUDITED_BY=storage_audit_v1
MARKER_EOF
mv -f "$TMP_MARKER" "$MARKER_FILE"

echo "Storage audit completed successfully. Marker recorded at $MARKER_FILE"
exit 0
AUDITOR_EOF

chmod 0755 "$INCIDENT_ROOT/bin/storage-audit"
echo "Setup completed successfully in $INCIDENT_ROOT."
