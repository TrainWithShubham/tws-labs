#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-040/incident" 2>/dev/null)" || fail "Directory ~/lnx-ch-040/incident does not exist."

MARKER="$INCIDENT_ROOT/reports/audit-success.marker"
[ -f "$MARKER" ] || fail "reports/audit-success.marker not found. Run ./bin/service-audit."

grep -Fxq "SERVICE_STATUS=RECOVERED" "$MARKER" || fail "Audit marker missing SERVICE_STATUS=RECOVERED."
grep -Fxq "SYSTEMD_ACTIVE=active" "$MARKER" || fail "Audit marker missing SYSTEMD_ACTIVE=active."
grep -Fxq "SYSTEMD_SUB=running" "$MARKER" || fail "Audit marker missing SYSTEMD_SUB=running."
grep -Fxq "LISTENING_STATE=ACTIVE" "$MARKER" || fail "Audit marker missing LISTENING_STATE=ACTIVE."
grep -Fxq "LISTENING_PORT=8080" "$MARKER" || fail "Audit marker missing LISTENING_PORT=8080."
grep -Fxq "UNIT_POLICY=RESTART_ON_FAILURE" "$MARKER" || fail "Audit marker missing UNIT_POLICY=RESTART_ON_FAILURE."
grep -Fxq "CONFIG_INTEGRITY=VERIFIED" "$MARKER" || fail "Audit marker missing CONFIG_INTEGRITY=VERIFIED."
grep -Fxq "AUDITED_BY=systemd_audit_v1" "$MARKER" || fail "Audit marker missing AUDITED_BY=systemd_audit_v1."

# Independent verification of underlying machine state
UNIT_FILE="$INCIDENT_ROOT/systemd/system/report-api.service"
ENV_FILE="$INCIDENT_ROOT/config/report-api.env"
SNAPSHOT_FILE="$INCIDENT_ROOT/run/systemd/daemon-reload.snapshot"
STATE_FILE="$INCIDENT_ROOT/run/systemd/report-api.state"

[ -f "$UNIT_FILE" ] || fail "Independent check failed: unit file is missing."
grep -Eq "^[[:space:]]*Restart=on-failure([[:space:]]|$)" "$UNIT_FILE" || fail "Independent check failed: unit does not set 'Restart=on-failure'."

exec_count="$(grep -c "^[[:space:]]*ExecStart=" "$UNIT_FILE" 2>/dev/null || true)"
[ "$exec_count" -eq 1 ] || fail "Independent check failed: unit must contain exactly one ExecStart directive."
grep -Eq "^[[:space:]]*ExecStart=%h/lnx-ch-040/incident/bin/report-api --mode=production[[:space:]]*\r?$" "$UNIT_FILE" || fail "Independent check failed: unit ExecStart must exactly match 'ExecStart=%h/lnx-ch-040/incident/bin/report-api --mode=production'."

[ -f "$ENV_FILE" ] || fail "Independent check failed: environment file is missing."
grep -Eq "^[[:space:]]*PORT=8080([[:space:]]|$)" "$ENV_FILE" || fail "Independent check failed: config does not set PORT=8080."

[ -f "$SNAPSHOT_FILE" ] || fail "Independent check failed: daemon-reload snapshot is missing."
LIVE_UNIT_HASH="$(sha256sum "$UNIT_FILE" | awk '{print $1}')"
LOADED_UNIT_HASH="$(awk -F= '/^LOADED_UNIT_HASH=/ {print $2}' "$SNAPSHOT_FILE")"
[ "$LIVE_UNIT_HASH" = "$LOADED_UNIT_HASH" ] || fail "Independent check failed: daemon-reload has not loaded the current unit file."

[ -f "$STATE_FILE" ] || fail "Independent check failed: service state file is missing."
S_ACTIVE="$(awk -F= '/^ACTIVE=/ {print $2}' "$STATE_FILE")"
S_SUB="$(awk -F= '/^SUB=/ {print $2}' "$STATE_FILE")"
S_LISTEN="$(awk -F= '/^LISTENING=/ {print $2}' "$STATE_FILE")"
S_PORT="$(awk -F= '/^LISTENING_PORT=/ {print $2}' "$STATE_FILE")"
S_UNIT_HASH="$(awk -F= '/^ACTIVE_UNIT_HASH=/ {print $2}' "$STATE_FILE")"
S_ENV_HASH="$(awk -F= '/^APPLIED_ENV_HASH=/ {print $2}' "$STATE_FILE")"

[ "$S_ACTIVE" = "active" ] || fail "Independent check failed: service is not in active state (found: '$S_ACTIVE')."
[ "$S_SUB" = "running" ] || fail "Independent check failed: service is not running (found: '$S_SUB')."
[ "$S_LISTEN" = "true" ] || fail "Independent check failed: service listener is not active."
[ "$S_PORT" = "8080" ] || fail "Independent check failed: service listener port is not 8080."

[ "$S_UNIT_HASH" = "$LOADED_UNIT_HASH" ] || fail "Independent check failed: active service unit configuration does not match reloaded unit."
LIVE_ENV_HASH="$(sha256sum "$ENV_FILE" | awk '{print $1}')"
[ "$S_ENV_HASH" = "$LIVE_ENV_HASH" ] || fail "Independent check failed: active service environment does not match current config/report-api.env."
