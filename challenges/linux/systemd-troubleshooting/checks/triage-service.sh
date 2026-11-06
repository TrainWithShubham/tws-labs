#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-040/incident" 2>/dev/null)" || fail "Directory ~/lnx-ch-040/incident does not exist."

REPORT="$INCIDENT_ROOT/reports/service-triage.env"
[ -f "$REPORT" ] || fail "reports/service-triage.env not found."

declare -A seen=()

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue

  if [[ "$line" =~ ^[^=]*[[:space:]]+= ]] || [[ "$line" =~ =[[:space:]]+ ]]; then
    fail "reports/service-triage.env contains illegal whitespace around '='."
  fi

  if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    fail "reports/service-triage.env contains malformed assignment: $line"
  fi

  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"

  if [[ "$val" =~ ^\" && ! "$val" =~ \"$ ]] || [[ "$val" =~ ^\' && ! "$val" =~ \'$ ]]; then
    fail "reports/service-triage.env contains unclosed quotation for $key."
  fi

  clean_val="$val"
  if [[ "$clean_val" =~ ^\"(.*)\"$ ]] || [[ "$clean_val" =~ ^\'(.*)\'$ ]]; then
    clean_val="${BASH_REMATCH[1]}"
  fi

  if [[ -n "${seen[$key]:-}" ]]; then
    fail "reports/service-triage.env contains duplicate key: $key."
  fi
  seen["$key"]="$clean_val"
done < "$REPORT"

for req in FAILED_SERVICE ACTIVE_STATE SUB_STATE EXIT_STATUS; do
  [ -n "${seen[$req]:-}" ] || fail "reports/service-triage.env missing required key: $req."
done

[ "${seen[FAILED_SERVICE]}" = "report-api.service" ] || fail "FAILED_SERVICE must equal 'report-api.service'."
[ "${seen[ACTIVE_STATE]}" = "failed" ] || fail "ACTIVE_STATE must equal 'failed'."
[ "${seen[SUB_STATE]}" = "failed" ] || fail "SUB_STATE must equal 'failed'."
[ "${seen[EXIT_STATUS]}" = "1/FAILURE" ] || fail "EXIT_STATUS must equal '1/FAILURE'."
