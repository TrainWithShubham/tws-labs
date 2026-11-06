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

# 2. Workspace Pre-Creation Safety Validation
WORKSPACE_DIR="$CANONICAL_BASE/lnx-ch-040"
INTENDED_ROOT="$WORKSPACE_DIR/incident"

if [ -e "$WORKSPACE_DIR" ]; then
  if [ -L "$WORKSPACE_DIR" ]; then
    echo "Fatal: $WORKSPACE_DIR is a symlink. Refusing to operate on symlinked workspace parent." >&2
    exit 1
  fi
  if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "Fatal: $WORKSPACE_DIR exists but is not a directory." >&2
    exit 1
  fi
else
  mkdir -m 0755 "$WORKSPACE_DIR"
fi

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
  mkdir -m 0755 "$INTENDED_ROOT"
fi

INCIDENT_ROOT="$(realpath -e "$INTENDED_ROOT" 2>/dev/null)" || {
  echo "Fatal: Failed to canonically resolve $INTENDED_ROOT." >&2
  exit 1
}

if [ "$(dirname "$INCIDENT_ROOT")" != "$CANONICAL_BASE/lnx-ch-040" ] || [ "$(basename "$INCIDENT_ROOT")" != "incident" ]; then
  echo "Fatal: INCIDENT_ROOT ($INCIDENT_ROOT) fails boundary verification." >&2
  exit 1
fi

# 3. Subdirectory Symlink Validation
for sub in bin config systemd systemd/system run run/systemd reports var var/log var/log/journal; do
  TARGET_PATH="$INCIDENT_ROOT/$sub"
  if [ -L "$TARGET_PATH" ]; then
    echo "Fatal: Subdirectory $TARGET_PATH is an unexpected symlink. Aborting." >&2
    exit 1
  fi
done

# 4. Idempotent Directory Reset (Zero Daemons / Zero Persistent Background Processes)
rm -rf "$INCIDENT_ROOT/run" "$INCIDENT_ROOT/reports" "$INCIDENT_ROOT/var"
mkdir -p "$INCIDENT_ROOT/bin" "$INCIDENT_ROOT/config" "$INCIDENT_ROOT/systemd/system" \
         "$INCIDENT_ROOT/run/systemd" "$INCIDENT_ROOT/reports" "$INCIDENT_ROOT/var/log/journal"
chmod 0755 "$INCIDENT_ROOT/bin" "$INCIDENT_ROOT/config" "$INCIDENT_ROOT/systemd/system" \
           "$INCIDENT_ROOT/run/systemd" "$INCIDENT_ROOT/reports" "$INCIDENT_ROOT/var/log/journal"

# 5. Provision Initial Unit File (Defective: Restart=no)
cat << 'UNIT_EOF' > "$INCIDENT_ROOT/systemd/system/report-api.service"
[Unit]
Description=Production Reporting API Service
After=network.target

[Service]
Type=simple
WorkingDirectory=%h/lnx-ch-040/incident
EnvironmentFile=%h/lnx-ch-040/incident/config/report-api.env
ExecStart=%h/lnx-ch-040/incident/bin/report-api --mode=production
Restart=no
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT_EOF
chmod 0644 "$INCIDENT_ROOT/systemd/system/report-api.service"

# 6. Provision Initial Environment File (Defective: PORT=80)
cat << 'ENV_EOF' > "$INCIDENT_ROOT/config/report-api.env"
# Production Reporting API Configuration
APP_ENV=production
PORT=80
DB_POOL=10
LOG_LEVEL=INFO
ENV_EOF
chmod 0644 "$INCIDENT_ROOT/config/report-api.env"

# 7. Provision Service Executable Simulation Stub
cat << 'STUB_EOF' > "$INCIDENT_ROOT/bin/report-api"
#!/bin/bash
# Simulation binary stub for report-api
echo "[INFO] report-api: simulation binary present"
exit 0
STUB_EOF
chmod 0755 "$INCIDENT_ROOT/bin/report-api"

# 8. Compute Initial Hashes and Snapshots
INITIAL_UNIT_HASH="$(sha256sum "$INCIDENT_ROOT/systemd/system/report-api.service" | awk '{print $1}')"
INITIAL_ENV_HASH="$(sha256sum "$INCIDENT_ROOT/config/report-api.env" | awk '{print $1}')"

cat << SNAP_EOF > "$INCIDENT_ROOT/run/systemd/daemon-reload.snapshot"
LOADED_UNIT_HASH=$INITIAL_UNIT_HASH
RELOAD_TIMESTAMP=$(date +%s)
SNAP_EOF
chmod 0644 "$INCIDENT_ROOT/run/systemd/daemon-reload.snapshot"

cat << STATE_EOF > "$INCIDENT_ROOT/run/systemd/report-api.state"
SERVICE=report-api.service
ACTIVE=failed
SUB=failed
RESULT=exit-code
EXIT_STATUS=1/FAILURE
LISTENING=false
LISTENING_PORT=none
ACTIVE_UNIT_HASH=$INITIAL_UNIT_HASH
APPLIED_ENV_HASH=$INITIAL_ENV_HASH
UPDATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STATE_EOF
chmod 0644 "$INCIDENT_ROOT/run/systemd/report-api.state"

# 9. Provision Initial Journald Diagnostic Log
cat << 'LOG_EOF' > "$INCIDENT_ROOT/var/log/journal/report-api.log"
Nov 05 09:15:10 node-01 systemd[1]: Starting Production Reporting API Service...
Nov 05 09:15:10 node-01 report-api[3810]: [INFO] Initializing reporting runtime (mode=production)...
Nov 05 09:15:11 node-01 report-api[3810]: [FATAL] Cannot bind listener to privileged port 80: PermissionDenied.
Nov 05 09:15:11 node-01 report-api[3810]: [FATAL] Unprivileged service policy requires PORT >= 1024 (expected: 8080 in config/report-api.env).
Nov 05 09:15:11 node-01 systemd[1]: report-api.service: Main process exited, code=exited, status=1/FAILURE
Nov 05 09:15:11 node-01 systemd[1]: report-api.service: Failed with result 'exit-code'.
Nov 05 09:15:11 node-01 systemd[1]: Failed to start Production Reporting API Service.
LOG_EOF
chmod 0644 "$INCIDENT_ROOT/var/log/journal/report-api.log"

# 10. Provision Incident Telemetry Status
cat << 'STATUS_EOF' > "$INCIDENT_ROOT/reports/incident.status"
[INCIDENT TELEMETRY] 2026-11-05T09:15:11Z
STATUS: CRITICAL_SERVICE_FAILURE
NOTE: This is a controlled systemd userland simulation. Service transitions are
file-backed and deterministic. No host services, background daemons, or sockets are created.
FAILED_SERVICE: report-api.service
UNIT_PATH: systemd/system/report-api.service
ACTIVE_STATE: failed
SUB_STATE: failed
EXIT_STATUS: 1/FAILURE
CONFIG_SOURCE: config/report-api.env
ACTIONS_REQUIRED:
  1. Triage failed service status via ./bin/systemctl and record reports/service-triage.env.
  2. Inspect journal logs via ./bin/journalctl and record reports/journal-triage.env.
  3. Remediate config/report-api.env (PORT=8080) and systemd/system/report-api.service (Restart=on-failure).
  4. Reload daemon via ./bin/systemctl daemon-reload, restart via ./bin/systemctl restart, and run ./bin/service-audit.
STATUS_EOF
chmod 0644 "$INCIDENT_ROOT/reports/incident.status"

# 11. Provision Command Shim: ./bin/systemctl
cat << 'SYSTEMCTL_EOF' > "$INCIDENT_ROOT/bin/systemctl"
#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"

UNIT_FILE="$ROOT/systemd/system/report-api.service"
ENV_FILE="$ROOT/config/report-api.env"
SNAPSHOT_FILE="$ROOT/run/systemd/daemon-reload.snapshot"
STATE_FILE="$ROOT/run/systemd/report-api.state"
JOURNAL_FILE="$ROOT/var/log/journal/report-api.log"

# Strict, restricted EnvironmentFile parser
parse_env() {
  local target="$1"
  declare -g -A PARSED_ENV=()
  [ -f "$target" ] || return 1

  local metachar_pattern='[\$\`&|;<>\!]'

  local comment_pattern='^[[:space:]]*[#;]'
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ $comment_pattern ]] && continue

    if [[ "$line" =~ ^[^=]*[[:space:]]+= ]] || [[ "$line" =~ =[[:space:]]+ ]]; then
      echo "[ERROR] Syntax error in $target: illegal whitespace around '='" >&2
      return 2
    fi

    if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      echo "[ERROR] Syntax error in $target: malformed assignment '$line'" >&2
      return 3
    fi

    local k="${BASH_REMATCH[1]}"
    local v="${BASH_REMATCH[2]}"

    if [[ -n "${PARSED_ENV[$k]:-}" ]]; then
      echo "[ERROR] Syntax error in $target: duplicate key '$k'" >&2
      return 4
    fi

    if [[ "$v" =~ $metachar_pattern ]]; then
      echo "[ERROR] Syntax error in $target: prohibited character in value for '$k'" >&2
      return 5
    fi

    if [[ "$v" =~ ^\"(.*)\"$ ]] || [[ "$v" =~ ^\'(.*)\'$ ]]; then
      v="${BASH_REMATCH[1]}"
    elif [[ "$v" =~ ^[\"\'] ]] || [[ "$v" =~ [\"\']$ ]]; then
      echo "[ERROR] Syntax error in $target: unclosed or mismatched quote for '$k'" >&2
      return 6
    fi

    if [[ "$v" =~ $metachar_pattern ]]; then
      echo "[ERROR] Syntax error in $target: prohibited character in value for '$k'" >&2
      return 5
    fi

    PARSED_ENV["$k"]="$v"
  done < "$target"
  return 0
}

normalize_unit() {
  local u="${1:-}"
  u="${u%.service}"
  echo "$u"
}

CMD="${1:-}"
shift || true

case "$CMD" in
  --failed|list-units)
    echo "  UNIT               LOAD   ACTIVE SUB    DESCRIPTION"
    if [ -f "$STATE_FILE" ]; then
      local a s
      a="$(awk -F= '/^ACTIVE=/ {print $2}' "$STATE_FILE")"
      s="$(awk -F= '/^SUB=/ {print $2}' "$STATE_FILE")"
      if [ "$a" = "failed" ] || [ "${1:-}" = "--failed" ] || [ "$CMD" = "--failed" ]; then
        if [ "$a" = "failed" ]; then
          printf "● %-18s loaded %-6s %-6s Production Reporting API Service\n" "report-api.service" "$a" "$s"
          echo ""
          echo "LOAD   = Reflects whether the unit definition was properly loaded."
          echo "ACTIVE = The high-level unit activation state, i.e. generalization of SUB."
          echo "SUB    = The low-level unit activation state, values depend on unit type."
          echo "1 loaded units listed."
          exit 0
        fi
      fi
    fi
    echo "0 loaded units listed."
    exit 0
    ;;

  status)
    TARGET="${1:-report-api.service}"
    NORM="$(normalize_unit "$TARGET")"
    if [ "$NORM" != "report-api" ]; then
      echo "Unit $TARGET could not be found." >&2
      exit 4
    fi

    if [ ! -f "$STATE_FILE" ]; then
      echo "Unit report-api.service could not be found." >&2
      exit 4
    fi

    CUR_ACTIVE="$(awk -F= '/^ACTIVE=/ {print $2}' "$STATE_FILE")"
    CUR_SUB="$(awk -F= '/^SUB=/ {print $2}' "$STATE_FILE")"
    CUR_RESULT="$(awk -F= '/^RESULT=/ {print $2}' "$STATE_FILE")"
    CUR_EXIT="$(awk -F= '/^EXIT_STATUS=/ {print $2}' "$STATE_FILE")"
    CUR_PORT="$(awk -F= '/^LISTENING_PORT=/ {print $2}' "$STATE_FILE")"

    if [ "$CUR_ACTIVE" = "failed" ]; then
      echo "× report-api.service - Production Reporting API Service"
      echo "     Loaded: loaded ($UNIT_FILE; enabled; vendor preset: enabled)"
      echo "     Active: failed (Result: $CUR_RESULT) since Thu 2026-11-05 09:15:11 UTC"
      echo "    Process: 3810 ExecStart=$ROOT/bin/report-api --mode=production (code=exited, status=$CUR_EXIT)"
      echo "   Main PID: 3810 (code=exited, status=$CUR_EXIT)"
      echo ""
      echo "Recent journal entries:"
      tail -n 6 "$JOURNAL_FILE" 2>/dev/null || true
      exit 3
    else
      echo "● report-api.service - Production Reporting API Service"
      echo "     Loaded: loaded ($UNIT_FILE; enabled; vendor preset: enabled)"
      echo "     Active: active (running) since Thu 2026-11-05 09:20:00 UTC"
      echo "     Status: \"Listening on simulated port $CUR_PORT (mode=production)\""
      echo "    Process: ExecStart=$ROOT/bin/report-api --mode=production (code=exited, status=0/SUCCESS)"
      echo ""
      echo "Recent journal entries:"
      tail -n 4 "$JOURNAL_FILE" 2>/dev/null || true
      exit 0
    fi
    ;;

  daemon-reload)
    if [ ! -f "$UNIT_FILE" ]; then
      echo "[ERROR] Unit file $UNIT_FILE missing." >&2
      exit 1
    fi
    exec_count="$(grep -c "^[[:space:]]*ExecStart=" "$UNIT_FILE" 2>/dev/null || true)"
    if [ "$exec_count" -ne 1 ] || ! grep -Eq "^[[:space:]]*ExecStart=%h/lnx-ch-040/incident/bin/report-api --mode=production[[:space:]]*\r?$" "$UNIT_FILE"; then
      echo "[ERROR] Unit file contains invalid, duplicate, or missing ExecStart directive." >&2
      exit 1
    fi
    NEW_UNIT_HASH="$(sha256sum "$UNIT_FILE" | awk '{print $1}')"
    cat << EOF > "$SNAPSHOT_FILE"
LOADED_UNIT_HASH=$NEW_UNIT_HASH
RELOAD_TIMESTAMP=$(date +%s)
EOF
    chmod 0644 "$SNAPSHOT_FILE"
    exit 0
    ;;

  restart|start)
    TARGET="${1:-report-api.service}"
    NORM="$(normalize_unit "$TARGET")"
    if [ "$NORM" != "report-api" ]; then
      echo "Unit $TARGET could not be found." >&2
      exit 4
    fi

    CURRENT_UNIT_HASH="$(sha256sum "$UNIT_FILE" | awk '{print $1}')"
    LOADED_UNIT_HASH="$(awk -F= '/^LOADED_UNIT_HASH=/ {print $2}' "$SNAPSHOT_FILE" 2>/dev/null || echo "")"

    if [ "$CURRENT_UNIT_HASH" != "$LOADED_UNIT_HASH" ]; then
      echo "Warning: The unit file, source configuration file or drop-ins of report-api.service changed on disk. Run 'systemctl daemon-reload' to reload units." >&2
    fi

    exec_count="$(grep -c "^[[:space:]]*ExecStart=" "$UNIT_FILE" 2>/dev/null || true)"
    if [ "$exec_count" -ne 1 ] || ! grep -Eq "^[[:space:]]*ExecStart=%h/lnx-ch-040/incident/bin/report-api --mode=production[[:space:]]*\r?$" "$UNIT_FILE"; then
      echo "Failed to restart report-api.service: Unit has invalid, duplicate, or missing ExecStart directive." >&2
      exit 1
    fi

    # Parse EnvironmentFile dynamically
    if ! parse_env "$ENV_FILE"; then
      cat << LOG_FAIL >> "$JOURNAL_FILE"
$(date +"%b %d %H:%M:%S") node-01 systemd[1]: Starting Production Reporting API Service...
$(date +"%b %d %H:%M:%S") node-01 systemd[1]: report-api.service: Failed to parse environment file $ENV_FILE
$(date +"%b %d %H:%M:%S") node-01 systemd[1]: report-api.service: Main process exited, code=exited, status=1/FAILURE
$(date +"%b %d %H:%M:%S") node-01 systemd[1]: Failed to start Production Reporting API Service.
LOG_FAIL
      cat << STATE_FAIL > "$STATE_FILE"
SERVICE=report-api.service
ACTIVE=failed
SUB=failed
RESULT=exit-code
EXIT_STATUS=1/FAILURE
LISTENING=false
LISTENING_PORT=none
ACTIVE_UNIT_HASH=$LOADED_UNIT_HASH
APPLIED_ENV_HASH=none
UPDATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STATE_FAIL
      echo "Job for report-api.service failed because the control process exited with error code." >&2
      echo "See \"systemctl status report-api.service\" and \"journalctl -xeu report-api.service\" for details." >&2
      exit 1
    fi

    APPLIED_ENV_HASH="$(sha256sum "$ENV_FILE" | awk '{print $1}')"
    CONFIG_PORT="${PARSED_ENV[PORT]:-}"

    if [ -z "$CONFIG_PORT" ] || ! [[ "$CONFIG_PORT" =~ ^[0-9]+$ ]] || [ "$CONFIG_PORT" -lt 1024 ] || [ "$CONFIG_PORT" -gt 65535 ]; then
      cat << LOG_PORT_FAIL >> "$JOURNAL_FILE"
$(date +"%b %d %H:%M:%S") node-01 systemd[1]: Starting Production Reporting API Service...
$(date +"%b %d %H:%M:%S") node-01 report-api[4102]: [FATAL] Cannot bind listener to port '${CONFIG_PORT}': PermissionDenied.
$(date +"%b %d %H:%M:%S") node-01 report-api[4102]: [FATAL] Unprivileged service policy requires PORT >= 1024 (expected: 8080 in config/report-api.env).
$(date +"%b %d %H:%M:%S") node-01 systemd[1]: report-api.service: Main process exited, code=exited, status=1/FAILURE
$(date +"%b %d %H:%M:%S") node-01 systemd[1]: report-api.service: Failed with result 'exit-code'.
$(date +"%b %d %H:%M:%S") node-01 systemd[1]: Failed to start Production Reporting API Service.
LOG_PORT_FAIL
      cat << STATE_PORT_FAIL > "$STATE_FILE"
SERVICE=report-api.service
ACTIVE=failed
SUB=failed
RESULT=exit-code
EXIT_STATUS=1/FAILURE
LISTENING=false
LISTENING_PORT=none
ACTIVE_UNIT_HASH=$LOADED_UNIT_HASH
APPLIED_ENV_HASH=$APPLIED_ENV_HASH
UPDATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STATE_PORT_FAIL
      echo "Job for report-api.service failed because the control process exited with error code." >&2
      echo "See \"systemctl status report-api.service\" and \"journalctl -xeu report-api.service\" for details." >&2
      exit 1
    fi

    # Startup succeeds when PORT >= 1024 (expected 8080)
    cat << LOG_SUCCESS >> "$JOURNAL_FILE"
$(date +"%b %d %H:%M:%S") node-01 systemd[1]: Starting Production Reporting API Service...
$(date +"%b %d %H:%M:%S") node-01 report-api[4200]: [INFO] Initializing reporting runtime (mode=production)...
$(date +"%b %d %H:%M:%S") node-01 report-api[4200]: [INFO] Service report-api successfully bound to simulated listener on port $CONFIG_PORT.
$(date +"%b %d %H:%M:%S") node-01 systemd[1]: Started Production Reporting API Service.
LOG_SUCCESS
    cat << STATE_SUCCESS > "$STATE_FILE"
SERVICE=report-api.service
ACTIVE=active
SUB=running
RESULT=success
EXIT_STATUS=0
LISTENING=true
LISTENING_PORT=$CONFIG_PORT
ACTIVE_UNIT_HASH=$LOADED_UNIT_HASH
APPLIED_ENV_HASH=$APPLIED_ENV_HASH
UPDATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STATE_SUCCESS
    exit 0
    ;;

  stop)
    TARGET="${1:-report-api.service}"
    cat << STATE_STOP > "$STATE_FILE"
SERVICE=report-api.service
ACTIVE=inactive
SUB=dead
RESULT=success
EXIT_STATUS=0
LISTENING=false
LISTENING_PORT=none
ACTIVE_UNIT_HASH=$(awk -F= '/^ACTIVE_UNIT_HASH=/ {print $2}' "$STATE_FILE" 2>/dev/null || echo "")
APPLIED_ENV_HASH=$(awk -F= '/^APPLIED_ENV_HASH=/ {print $2}' "$STATE_FILE" 2>/dev/null || echo "")
UPDATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STATE_STOP
    exit 0
    ;;

  is-active)
    TARGET="${1:-report-api.service}"
    if [ -f "$STATE_FILE" ]; then
      A="$(awk -F= '/^ACTIVE=/ {print $2}' "$STATE_FILE")"
      echo "$A"
      [ "$A" = "active" ] && exit 0 || exit 3
    fi
    echo "unknown"
    exit 3
    ;;

  cat)
    TARGET="${1:-report-api.service}"
    NORM="$(normalize_unit "$TARGET")"
    if [ "$NORM" != "report-api" ]; then
      echo "Unit $TARGET could not be found." >&2
      exit 4
    fi
    cat "$UNIT_FILE"
    exit 0
    ;;

  *)
    echo "Unsupported command '$CMD'. Supported: status, --failed, daemon-reload, restart, start, stop, is-active, cat." >&2
    exit 1
    ;;
esac
SYSTEMCTL_EOF
chmod 0755 "$INCIDENT_ROOT/bin/systemctl"

# 12. Provision Command Shim: ./bin/journalctl
cat << 'JOURNALCTL_EOF' > "$INCIDENT_ROOT/bin/journalctl"
#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
JOURNAL_FILE="$ROOT/var/log/journal/report-api.log"

LINES=0
while [ $# -gt 0 ]; do
  case "$1" in
    -u|--unit) shift ;;
    -n|--lines)
      shift
      LINES="${1:-0}"
      ;;
    -n*)
      LINES="${1#-n}"
      ;;
    -e|--pager-end|-x|--catalog|--no-pager|-xe|-xeu)
      ;;
    report-api.service|report-api)
      ;;
  esac
  shift || true
done

[ -f "$JOURNAL_FILE" ] || { echo "No journal logs found." >&2; exit 0; }

if [ "$LINES" -gt 0 ] 2>/dev/null; then
  tail -n "$LINES" "$JOURNAL_FILE"
else
  cat "$JOURNAL_FILE"
fi
exit 0
JOURNALCTL_EOF
chmod 0755 "$INCIDENT_ROOT/bin/journalctl"

# 13. Provision Recovery Audit Tool: ./bin/service-audit
cat << 'AUDIT_EOF' > "$INCIDENT_ROOT/bin/service-audit"
#!/bin/bash
set -euo pipefail

fail() {
  echo "[AUDIT FAILED] $*" >&2
  exit 1
}

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"

UNIT_FILE="$ROOT/systemd/system/report-api.service"
ENV_FILE="$ROOT/config/report-api.env"
SNAPSHOT_FILE="$ROOT/run/systemd/daemon-reload.snapshot"
STATE_FILE="$ROOT/run/systemd/report-api.state"

# 1. Inspect unit file
[ -f "$UNIT_FILE" ] || fail "Unit file $UNIT_FILE is missing."
grep -Eq "^[[:space:]]*Restart=on-failure([[:space:]]|$)" "$UNIT_FILE" || fail "Unit file must configure 'Restart=on-failure'."
exec_count="$(grep -c "^[[:space:]]*ExecStart=" "$UNIT_FILE" 2>/dev/null || true)"
[ "$exec_count" -eq 1 ] || fail "Unit file must contain exactly one ExecStart directive."
grep -Eq "^[[:space:]]*ExecStart=%h/lnx-ch-040/incident/bin/report-api --mode=production[[:space:]]*\r?$" "$UNIT_FILE" || fail "Unit file ExecStart must exactly match 'ExecStart=%h/lnx-ch-040/incident/bin/report-api --mode=production'."

# 2. Inspect environment file using strict parser
[ -f "$ENV_FILE" ] || fail "Configuration file $ENV_FILE is missing."
declare -A ENV_MAP=()
metachar_pattern='[\$\`&|;<>\!]'
comment_pattern='^[[:space:]]*[#;]'

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  [[ "$line" =~ $comment_pattern ]] && continue

  if [[ "$line" =~ ^[^=]*[[:space:]]+= ]] || [[ "$line" =~ =[[:space:]]+ ]]; then
    fail "config/report-api.env contains illegal whitespace around '='."
  fi
  if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    fail "config/report-api.env contains malformed assignment."
  fi

  k="${BASH_REMATCH[1]}"
  v="${BASH_REMATCH[2]}"

  [ -z "${ENV_MAP[$k]:-}" ] || fail "config/report-api.env contains duplicate key: $k."
  if [[ "$v" =~ $metachar_pattern ]]; then
    fail "config/report-api.env contains prohibited characters."
  fi

  if [[ "$v" =~ ^\"(.*)\"$ ]] || [[ "$v" =~ ^\'(.*)\'$ ]]; then
    v="${BASH_REMATCH[1]}"
  elif [[ "$v" =~ ^[\"\'] ]] || [[ "$v" =~ [\"\']$ ]]; then
    fail "config/report-api.env contains unclosed quote for $k."
  fi

  if [[ "$v" =~ $metachar_pattern ]]; then
    fail "config/report-api.env contains prohibited characters."
  fi

  ENV_MAP["$k"]="$v"
done < "$ENV_FILE"

for req in APP_ENV PORT DB_POOL LOG_LEVEL; do
  [ -n "${ENV_MAP[$req]:-}" ] || fail "config/report-api.env missing required key: $req."
done

[ "${ENV_MAP[PORT]}" = "8080" ] || fail "config/report-api.env PORT must equal '8080' (found: '${ENV_MAP[PORT]}')."
[ "${ENV_MAP[APP_ENV]}" = "production" ] || fail "config/report-api.env APP_ENV must equal 'production'."
[ "${ENV_MAP[DB_POOL]}" = "10" ] || fail "config/report-api.env DB_POOL must equal '10'."
[ "${ENV_MAP[LOG_LEVEL]}" = "INFO" ] || fail "config/report-api.env LOG_LEVEL must equal 'INFO'."

# 3. Verify daemon-reload loaded current unit file
[ -f "$SNAPSHOT_FILE" ] || fail "daemon-reload snapshot missing. Run ./bin/systemctl daemon-reload."
LIVE_UNIT_HASH="$(sha256sum "$UNIT_FILE" | awk '{print $1}')"
LOADED_UNIT_HASH="$(awk -F= '/^LOADED_UNIT_HASH=/ {print $2}' "$SNAPSHOT_FILE")"
[ "$LIVE_UNIT_HASH" = "$LOADED_UNIT_HASH" ] || fail "Unit file changed on disk but was not reloaded. Run ./bin/systemctl daemon-reload."

# 4. Verify service state
[ -f "$STATE_FILE" ] || fail "Service state file missing. Start the service with ./bin/systemctl restart report-api.service."
S_ACTIVE="$(awk -F= '/^ACTIVE=/ {print $2}' "$STATE_FILE")"
S_SUB="$(awk -F= '/^SUB=/ {print $2}' "$STATE_FILE")"
S_LISTEN="$(awk -F= '/^LISTENING=/ {print $2}' "$STATE_FILE")"
S_PORT="$(awk -F= '/^LISTENING_PORT=/ {print $2}' "$STATE_FILE")"
S_UNIT_HASH="$(awk -F= '/^ACTIVE_UNIT_HASH=/ {print $2}' "$STATE_FILE")"
S_ENV_HASH="$(awk -F= '/^APPLIED_ENV_HASH=/ {print $2}' "$STATE_FILE")"

[ "$S_ACTIVE" = "active" ] || fail "Service is not active (state: '$S_ACTIVE'). Run ./bin/systemctl restart report-api.service."
[ "$S_SUB" = "running" ] || fail "Service sub-state is not running (sub: '$S_SUB')."
[ "$S_LISTEN" = "true" ] || fail "Service listener state is not active."
[ "$S_PORT" = "8080" ] || fail "Service listener port is not 8080."

[ "$S_UNIT_HASH" = "$LOADED_UNIT_HASH" ] || fail "Running service unit configuration does not match reloaded unit."
LIVE_ENV_HASH="$(sha256sum "$ENV_FILE" | awk '{print $1}')"
[ "$S_ENV_HASH" = "$LIVE_ENV_HASH" ] || fail "Running service environment does not match current config/report-api.env. Run ./bin/systemctl restart report-api.service."

# 5. Generate audit marker
cat << 'MARKER_EOF' > "$ROOT/reports/audit-success.marker"
SERVICE_STATUS=RECOVERED
SYSTEMD_ACTIVE=active
SYSTEMD_SUB=running
LISTENING_STATE=ACTIVE
LISTENING_PORT=8080
UNIT_POLICY=RESTART_ON_FAILURE
CONFIG_INTEGRITY=VERIFIED
AUDITED_BY=systemd_audit_v1
MARKER_EOF

echo "[AUDIT OK] Service recovered and verified. Generated reports/audit-success.marker."
exit 0
AUDIT_EOF
chmod 0755 "$INCIDENT_ROOT/bin/service-audit"

echo "Systemd troubleshooting incident environment provisioned successfully."
