#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/incident" 2>/dev/null)" || fail "Directory ~/incident does not exist."

REPORT="$INCIDENT_ROOT/reports/root-cause.env"
[ -f "$REPORT" ] || fail "incident/reports/root-cause.env not found."

declare -A seen=()

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue

  if [[ "$line" =~ ^[^=]*[[:space:]]+= ]] || [[ "$line" =~ =[[:space:]]+ ]]; then
    fail "reports/root-cause.env contains illegal whitespace around '='."
  fi

  if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    fail "reports/root-cause.env contains malformed assignment: $line"
  fi

  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"

  if [[ "$val" =~ ^\" && ! "$val" =~ \"$ ]] || [[ "$val" =~ ^\' && ! "$val" =~ \'$ ]]; then
    fail "reports/root-cause.env contains unclosed quotation for $key."
  fi

  clean_val="$val"
  if [[ "$clean_val" =~ ^\"(.*)\"$ ]] || [[ "$clean_val" =~ ^\'(.*)\'$ ]]; then
    clean_val="${BASH_REMATCH[1]}"
  fi

  if [[ -n "${seen[$key]:-}" ]]; then
    fail "reports/root-cause.env contains duplicate key: $key."
  fi
  seen["$key"]="$clean_val"
done < "$REPORT"

for req in CULPRIT_ENDPOINT ERROR_SIGNATURE ROOT_CAUSE; do
  [ -n "${seen[$req]:-}" ] || fail "reports/root-cause.env missing required key: $req."
done

[ "${seen[CULPRIT_ENDPOINT]}" = "postgres-primary:5432" ] || fail "CULPRIT_ENDPOINT must equal 'postgres-primary:5432'."
[ "${seen[ERROR_SIGNATURE]}" = "ConnectionRefused" ] || fail "ERROR_SIGNATURE must equal 'ConnectionRefused'."
[ "${seen[ROOT_CAUSE]}" = "DOWNSTREAM_TIMEOUT" ] || fail "ROOT_CAUSE must equal 'DOWNSTREAM_TIMEOUT'."
