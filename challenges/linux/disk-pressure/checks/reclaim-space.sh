#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/incident" 2>/dev/null)" || fail "Directory ~/incident does not exist."

LOG_FILE="$INCIDENT_ROOT/var/log/app.log"
ARCHIVE_FILE="$INCIDENT_ROOT/var/log/app.log.1.gz"

[ -f "$LOG_FILE" ] || fail "incident/var/log/app.log does not exist (do not unlink the active log file)."
LOG_SIZE=$(wc -c < "$LOG_FILE")
[ "$LOG_SIZE" -le 1024 ] || fail "incident/var/log/app.log is $LOG_SIZE bytes (must be truncated to <= 1024 bytes)."

[ -f "$ARCHIVE_FILE" ] || fail "Historical archive incident/var/log/app.log.1.gz not found."
[ -s "$ARCHIVE_FILE" ] || fail "Historical archive incident/var/log/app.log.1.gz is empty."

ARCHIVE_SIZE=$(wc -c < "$ARCHIVE_FILE")
[ "$ARCHIVE_SIZE" -gt 1000 ] || fail "Historical archive incident/var/log/app.log.1.gz appears truncated."

gzip -t "$ARCHIVE_FILE" 2>/dev/null || fail "incident/var/log/app.log.1.gz is not a valid gzip archive."

DIR_SIZE_KB=$(du -sk "$INCIDENT_ROOT/var/log" 2>/dev/null | awk '{print $1}')
[ "$DIR_SIZE_KB" -le 10240 ] || fail "incident/var/log still occupies ${DIR_SIZE_KB}KB (must be <= 10MB)."
