#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/incident" 2>/dev/null)" || fail "Directory ~/incident does not exist."

REPORT="$INCIDENT_ROOT/reports/triage.env"
[ -f "$REPORT" ] || fail "incident/reports/triage.env not found."

declare -A seen=()

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue

  if [[ "$line" =~ ^[^=]*[[:space:]]+= ]] || [[ "$line" =~ =[[:space:]]+ ]]; then
    fail "reports/triage.env contains illegal whitespace around '='."
  fi

  if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    fail "reports/triage.env contains malformed assignment: $line"
  fi

  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"

  if [[ "$val" =~ ^\" && ! "$val" =~ \"$ ]] || [[ "$val" =~ ^\' && ! "$val" =~ \'$ ]]; then
    fail "reports/triage.env contains unclosed quotation for $key."
  fi

  clean_val="$val"
  if [[ "$clean_val" =~ ^\"(.*)\"$ ]] || [[ "$clean_val" =~ ^\'(.*)\'$ ]]; then
    clean_val="${BASH_REMATCH[1]}"
  fi

  if [[ -n "${seen[$key]:-}" ]]; then
    fail "reports/triage.env contains duplicate key: $key."
  fi
  seen["$key"]="$clean_val"
done < "$REPORT"

for req in ROGUE_PID PARENT_PID ROGUE_QUEUE CHILD_PID BATCH_ID WORKER_NAME; do
  [ -n "${seen[$req]:-}" ] || fail "reports/triage.env missing required key: $req."
done

[ "${seen[ROGUE_QUEUE]}" = "reports" ] || fail "ROGUE_QUEUE must equal 'reports'."
[ "${seen[BATCH_ID]}" = "9021" ] || fail "BATCH_ID must equal '9021'."
[ "${seen[WORKER_NAME]}" = "report-worker" ] || fail "WORKER_NAME must equal 'report-worker'."

CHILD_PID_FILE="$INCIDENT_ROOT/run/rogue-child.pid"
ROGUE_PID_FILE="$INCIDENT_ROOT/run/rogue-worker.pid"
SUPER_PID_FILE="$INCIDENT_ROOT/run/supervisor.pid"

[ -f "$CHILD_PID_FILE" ] || fail "Reference PID file run/rogue-child.pid missing."
[ -f "$ROGUE_PID_FILE" ] || fail "Reference PID file run/rogue-worker.pid missing."
[ -f "$SUPER_PID_FILE" ] || fail "Reference PID file run/supervisor.pid missing."

ACTUAL_CHILD_PID="$(cat "$CHILD_PID_FILE" 2>/dev/null || echo "")"
ACTUAL_ROGUE_PID="$(cat "$ROGUE_PID_FILE" 2>/dev/null || echo "")"
ACTUAL_SUPER_PID="$(cat "$SUPER_PID_FILE" 2>/dev/null || echo "")"

[ -n "$ACTUAL_CHILD_PID" ] || fail "run/rogue-child.pid is empty."
[ -n "$ACTUAL_ROGUE_PID" ] || fail "run/rogue-worker.pid is empty."
[ -n "$ACTUAL_SUPER_PID" ] || fail "run/supervisor.pid is empty."

[ "${seen[CHILD_PID]}" = "$ACTUAL_CHILD_PID" ] || fail "CHILD_PID (${seen[CHILD_PID]}) does not match active rogue child PID ($ACTUAL_CHILD_PID)."
[ "${seen[ROGUE_PID]}" = "$ACTUAL_ROGUE_PID" ] || fail "ROGUE_PID (${seen[ROGUE_PID]}) does not match active rogue worker PID ($ACTUAL_ROGUE_PID)."
[ "${seen[PARENT_PID]}" = "$ACTUAL_SUPER_PID" ] || fail "PARENT_PID (${seen[PARENT_PID]}) does not match active supervisor PID ($ACTUAL_SUPER_PID)."
