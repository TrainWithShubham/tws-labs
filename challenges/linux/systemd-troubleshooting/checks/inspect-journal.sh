#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-040/incident" 2>/dev/null)" || fail "Directory ~/lnx-ch-040/incident does not exist."

REPORT="$INCIDENT_ROOT/reports/journal-triage.env"
[ -f "$REPORT" ] || fail "reports/journal-triage.env not found."

declare -A seen=()

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue

  if [[ "$line" =~ ^[^=]*[[:space:]]+= ]] || [[ "$line" =~ =[[:space:]]+ ]]; then
    fail "reports/journal-triage.env contains illegal whitespace around '='."
  fi

  if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    fail "reports/journal-triage.env contains malformed assignment: $line"
  fi

  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"

  if [[ "$val" =~ ^\" && ! "$val" =~ \"$ ]] || [[ "$val" =~ ^\' && ! "$val" =~ \'$ ]]; then
    fail "reports/journal-triage.env contains unclosed quotation for $key."
  fi

  clean_val="$val"
  if [[ "$clean_val" =~ ^\"(.*)\"$ ]] || [[ "$clean_val" =~ ^\'(.*)\'$ ]]; then
    clean_val="${BASH_REMATCH[1]}"
  fi

  if [[ -n "${seen[$key]:-}" ]]; then
    fail "reports/journal-triage.env contains duplicate key: $key."
  fi
  seen["$key"]="$clean_val"
done < "$REPORT"

for req in ERROR_SIGNATURE CONFIG_SOURCE REJECTED_PORT ROOT_CAUSE; do
  [ -n "${seen[$req]:-}" ] || fail "reports/journal-triage.env missing required key: $req."
done

[ "${seen[ERROR_SIGNATURE]}" = "ERR_PRIVILEGED_PORT" ] || fail "ERROR_SIGNATURE must equal 'ERR_PRIVILEGED_PORT'."
[ "${seen[CONFIG_SOURCE]}" = "config/report-api.env" ] || fail "CONFIG_SOURCE must equal 'config/report-api.env'."
[ "${seen[REJECTED_PORT]}" = "80" ] || fail "REJECTED_PORT must equal '80'."
[ "${seen[ROOT_CAUSE]}" = "UNPRIVILEGED_PORT_VIOLATION" ] || fail "ROOT_CAUSE must equal 'UNPRIVILEGED_PORT_VIOLATION'."
