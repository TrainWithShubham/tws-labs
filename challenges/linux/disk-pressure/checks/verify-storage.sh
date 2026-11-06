#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/incident" 2>/dev/null)" || fail "Directory ~/incident does not exist."

MARKER="$INCIDENT_ROOT/reports/audit-success.marker"
[ -f "$MARKER" ] || fail "incident/reports/audit-success.marker not found. Run ./bin/storage-audit."

grep -Fxq "STORAGE_PRESSURE=RESOLVED" "$MARKER" || fail "Audit marker missing STORAGE_PRESSURE=RESOLVED."
grep -Fxq "BLOCK_USAGE_MB=OK" "$MARKER" || fail "Audit marker missing BLOCK_USAGE_MB=OK."
grep -Fxq "INODE_COUNT=OK" "$MARKER" || fail "Audit marker missing INODE_COUNT=OK."
grep -Fxq "RETENTION_POLICY=COMPLIANT" "$MARKER" || fail "Audit marker missing RETENTION_POLICY=COMPLIANT."
grep -Fxq "ROTATION_CONFIG=VERIFIED" "$MARKER" || fail "Audit marker missing ROTATION_CONFIG=VERIFIED."
grep -Fxq "AUDITED_BY=storage_audit_v1" "$MARKER" || fail "Audit marker missing AUDITED_BY=storage_audit_v1."

# Independent verification of real state
CACHE_COUNT=$(find "$INCIDENT_ROOT/var/cache" -maxdepth 1 -type f 2>/dev/null | wc -l)
[ "$CACHE_COUNT" -le 50 ] || fail "Independent check failed: var/cache contains $CACHE_COUNT files."

LOG_FILE="$INCIDENT_ROOT/var/log/app.log"
[ -f "$LOG_FILE" ] || fail "Independent check failed: var/log/app.log is missing."
[ "$(wc -c < "$LOG_FILE")" -le 1024 ] || fail "Independent check failed: active log size exceeds 1024 bytes."

ARCHIVE_FILE="$INCIDENT_ROOT/var/log/app.log.1.gz"
[ -f "$ARCHIVE_FILE" ] || fail "Independent check failed: archive var/log/app.log.1.gz is missing."
gzip -t "$ARCHIVE_FILE" 2>/dev/null || fail "Independent check failed: archive is corrupt."

SERVICE_CONF="$INCIDENT_ROOT/config/service.conf"
[ -f "$SERVICE_CONF" ] || fail "Independent check failed: config/service.conf is missing."
grep -Eq "^[[:space:]]*LOG_LEVEL=WARN([[:space:]]|$)" "$SERVICE_CONF" || fail "Independent check failed: config/service.conf does not set LOG_LEVEL=WARN."

LOGROTATE_CONF="$INCIDENT_ROOT/config/logrotate.conf"
[ -f "$LOGROTATE_CONF" ] || fail "Independent check failed: config/logrotate.conf is missing."

RAW_PATH=$(awk '/^[[:space:]]*[^#[:space:]]/ {gsub(/\"/, ""); print $1; exit}' "$LOGROTATE_CONF")
[ -n "$RAW_PATH" ] || fail "config/logrotate.conf does not define a valid log target path."
RESOLVED_CONF_LOG=$(realpath -m "$RAW_PATH" 2>/dev/null || echo "")
ACTUAL_LOG=$(realpath -e "$LOG_FILE")
[ "$RESOLVED_CONF_LOG" = "$ACTUAL_LOG" ] || fail "config/logrotate.conf must target $ACTUAL_LOG (found $RAW_PATH)."

grep -Eq "^[[:space:]]*size[[:space:]]+10M([[:space:]]|$)" "$LOGROTATE_CONF" || fail "config/logrotate.conf missing 'size 10M' directive."
grep -Eq "^[[:space:]]*rotate[[:space:]]+5([[:space:]]|$)" "$LOGROTATE_CONF" || fail "config/logrotate.conf missing 'rotate 5' directive."
grep -Eq "^[[:space:]]*compress([[:space:]]|$)" "$LOGROTATE_CONF" || fail "config/logrotate.conf missing 'compress' directive."
grep -Eq "^[[:space:]]*missingok([[:space:]]|$)" "$LOGROTATE_CONF" || fail "config/logrotate.conf missing 'missingok' directive."
grep -Eq "^[[:space:]]*notifempty([[:space:]]|$)" "$LOGROTATE_CONF" || fail "config/logrotate.conf missing 'notifempty' directive."
