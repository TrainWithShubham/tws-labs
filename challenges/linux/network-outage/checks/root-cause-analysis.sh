#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-050/incident" 2>/dev/null)" || fail "Directory ~/lnx-ch-050/incident does not exist."

REPORT="$INCIDENT_ROOT/reports/root-cause.env"
[ -f "$REPORT" ] || fail "reports/root-cause.env not found."

declare -A seen=()
metachar_pattern='[\$\`&|;<>\!]'
comment_pattern='^[[:space:]]*[#;]'

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  [[ "$line" =~ $comment_pattern ]] && continue

  if [[ "$line" =~ ^[^=]*[[:space:]]+= ]] || [[ "$line" =~ =[[:space:]]+ ]]; then
    fail "reports/root-cause.env contains illegal whitespace around '='."
  fi

  if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    fail "reports/root-cause.env contains malformed assignment: $line"
  fi

  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"

  [ -z "${seen[$key]:-}" ] || fail "reports/root-cause.env contains duplicate key: $key."

  if [[ "$val" =~ $metachar_pattern ]]; then
    fail "reports/root-cause.env contains prohibited characters."
  fi

  if [[ "$val" =~ ^\"(.*)\"$ ]] || [[ "$val" =~ ^\'(.*)\'$ ]]; then
    val="${BASH_REMATCH[1]}"
  elif [[ "$val" =~ ^[\"\'] ]] || [[ "$val" =~ [\"\']$ ]]; then
    fail "reports/root-cause.env contains unclosed quotation for $key."
  fi

  if [[ "$val" =~ $metachar_pattern ]]; then
    fail "reports/root-cause.env contains prohibited characters."
  fi

  seen["$key"]="$val"
done < "$REPORT"

for req in FAILURE_TYPE MISSING_DESTINATION REQUIRED_GATEWAY OUTGOING_INTERFACE; do
  [ -n "${seen[$req]:-}" ] || fail "reports/root-cause.env missing required key: $req."
done

[ "${seen[FAILURE_TYPE]}" = "MISSING_ROUTE" ] || fail "FAILURE_TYPE must equal 'MISSING_ROUTE'."
[ "${seen[MISSING_DESTINATION]}" = "10.0.2.0/24" ] || fail "MISSING_DESTINATION must equal '10.0.2.0/24'."
[ "${seen[REQUIRED_GATEWAY]}" = "10.0.1.1" ] || fail "REQUIRED_GATEWAY must equal '10.0.1.1'."
[ "${seen[OUTGOING_INTERFACE]}" = "eth0" ] || fail "OUTGOING_INTERFACE must equal 'eth0'."
