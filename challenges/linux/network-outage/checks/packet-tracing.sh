#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-050/incident" 2>/dev/null)" || fail "Directory ~/lnx-ch-050/incident does not exist."

REPORT="$INCIDENT_ROOT/reports/packet-trace.env"
[ -f "$REPORT" ] || fail "reports/packet-trace.env not found."

declare -A seen=()
metachar_pattern='[\$\`&|;<>\!]'
comment_pattern='^[[:space:]]*[#;]'

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  [[ "$line" =~ $comment_pattern ]] && continue

  if [[ "$line" =~ ^[^=]*[[:space:]]+= ]] || [[ "$line" =~ =[[:space:]]+ ]]; then
    fail "reports/packet-trace.env contains illegal whitespace around '='."
  fi

  if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    fail "reports/packet-trace.env contains malformed assignment: $line"
  fi

  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"

  [ -z "${seen[$key]:-}" ] || fail "reports/packet-trace.env contains duplicate key: $key."

  if [[ "$val" =~ $metachar_pattern ]]; then
    fail "reports/packet-trace.env contains prohibited characters."
  fi

  if [[ "$val" =~ ^\"(.*)\"$ ]] || [[ "$val" =~ ^\'(.*)\'$ ]]; then
    val="${BASH_REMATCH[1]}"
  elif [[ "$val" =~ ^[\"\'] ]] || [[ "$val" =~ [\"\']$ ]]; then
    fail "reports/packet-trace.env contains unclosed quotation for $key."
  fi

  if [[ "$val" =~ $metachar_pattern ]]; then
    fail "reports/packet-trace.env contains prohibited characters."
  fi

  seen["$key"]="$val"
done < "$REPORT"

for req in TARGET_IP PING_RESULT ERROR_MESSAGE LAST_HOP; do
  [ -n "${seen[$req]:-}" ] || fail "reports/packet-trace.env missing required key: $req."
done

[ "${seen[TARGET_IP]}" = "10.0.2.100" ] || fail "TARGET_IP must equal '10.0.2.100'."
[ "${seen[PING_RESULT]}" = "UNREACHABLE" ] || fail "PING_RESULT must equal 'UNREACHABLE'."
[ "${seen[ERROR_MESSAGE]}" = "Network is unreachable" ] || fail "ERROR_MESSAGE must equal 'Network is unreachable'."
[ "${seen[LAST_HOP]}" = "NONE" ] || fail "LAST_HOP must equal 'NONE'."
