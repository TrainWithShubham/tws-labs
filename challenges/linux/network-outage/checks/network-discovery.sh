#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-050/incident" 2>/dev/null)" || fail "Directory ~/lnx-ch-050/incident does not exist."

REPORT="$INCIDENT_ROOT/reports/discovery.env"
[ -f "$REPORT" ] || fail "reports/discovery.env not found."

declare -A seen=()
metachar_pattern='[\$\`&|;<>\!]'
comment_pattern='^[[:space:]]*[#;]'

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  [[ "$line" =~ $comment_pattern ]] && continue

  if [[ "$line" =~ ^[^=]*[[:space:]]+= ]] || [[ "$line" =~ =[[:space:]]+ ]]; then
    fail "reports/discovery.env contains illegal whitespace around '='."
  fi

  if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    fail "reports/discovery.env contains malformed assignment: $line"
  fi

  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"

  [ -z "${seen[$key]:-}" ] || fail "reports/discovery.env contains duplicate key: $key."

  if [[ "$val" =~ $metachar_pattern ]]; then
    fail "reports/discovery.env contains prohibited characters."
  fi

  if [[ "$val" =~ ^\"(.*)\"$ ]] || [[ "$val" =~ ^\'(.*)\'$ ]]; then
    val="${BASH_REMATCH[1]}"
  elif [[ "$val" =~ ^[\"\'] ]] || [[ "$val" =~ [\"\']$ ]]; then
    fail "reports/discovery.env contains unclosed quotation for $key."
  fi

  if [[ "$val" =~ $metachar_pattern ]]; then
    fail "reports/discovery.env contains prohibited characters."
  fi

  seen["$key"]="$val"
done < "$REPORT"

for req in CLIENT_IP DNS_SERVER RESOLVED_IP DNS_STATUS; do
  [ -n "${seen[$req]:-}" ] || fail "reports/discovery.env missing required key: $req."
done

[ "${seen[CLIENT_IP]}" = "10.0.1.10" ] || fail "CLIENT_IP must equal '10.0.1.10'."
[ "${seen[DNS_SERVER]}" = "10.0.2.53" ] || fail "DNS_SERVER must equal '10.0.2.53'."
[ "${seen[RESOLVED_IP]}" = "10.0.2.100" ] || fail "RESOLVED_IP must equal '10.0.2.100'."
[ "${seen[DNS_STATUS]}" = "RESOLVED" ] || fail "DNS_STATUS must equal 'RESOLVED'."
