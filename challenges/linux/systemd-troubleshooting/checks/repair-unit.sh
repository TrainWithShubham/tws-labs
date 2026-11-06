#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-040/incident" 2>/dev/null)" || fail "Directory ~/lnx-ch-040/incident does not exist."

UNIT_FILE="$INCIDENT_ROOT/systemd/system/report-api.service"
ENV_FILE="$INCIDENT_ROOT/config/report-api.env"

# 1. Validate unit directives
[ -f "$UNIT_FILE" ] || fail "Unit file systemd/system/report-api.service missing."
grep -Eq "^[[:space:]]*Restart=on-failure([[:space:]]|$)" "$UNIT_FILE" || fail "Unit file must set 'Restart=on-failure'."

exec_count="$(grep -c "^[[:space:]]*ExecStart=" "$UNIT_FILE" 2>/dev/null || true)"
[ "$exec_count" -eq 1 ] || fail "Unit file must contain exactly one ExecStart directive."
grep -Eq "^[[:space:]]*ExecStart=%h/lnx-ch-040/incident/bin/report-api --mode=production[[:space:]]*\r?$" "$UNIT_FILE" || fail "Unit file ExecStart must exactly match 'ExecStart=%h/lnx-ch-040/incident/bin/report-api --mode=production'."

if grep -Eq "^[[:space:]]*Restart=no([[:space:]]|$)" "$UNIT_FILE"; then
  fail "Unit file still contains 'Restart=no'."
fi

# 2. Validate environment file using strict parser
[ -f "$ENV_FILE" ] || fail "Configuration file config/report-api.env missing."

declare -A seen=()
comment_pattern='^[[:space:]]*[#;]'
metachar_pattern='[\$\`&|;<>\!]'

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  [[ "$line" =~ $comment_pattern ]] && continue

  if [[ "$line" =~ ^[^=]*[[:space:]]+= ]] || [[ "$line" =~ =[[:space:]]+ ]]; then
    fail "config/report-api.env contains illegal whitespace around '='."
  fi

  if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    fail "config/report-api.env contains malformed assignment: $line"
  fi

  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"

  [ -z "${seen[$key]:-}" ] || fail "config/report-api.env contains duplicate key: $key."

  if [[ "$val" =~ $metachar_pattern ]]; then
    fail "config/report-api.env contains prohibited characters."
  fi

  if [[ "$val" =~ ^\"(.*)\"$ ]] || [[ "$val" =~ ^\'(.*)\'$ ]]; then
    val="${BASH_REMATCH[1]}"
  elif [[ "$val" =~ ^[\"\'] ]] || [[ "$val" =~ [\"\']$ ]]; then
    fail "config/report-api.env contains unclosed quotation for $key."
  fi

  if [[ "$val" =~ $metachar_pattern ]]; then
    fail "config/report-api.env contains prohibited characters."
  fi

  seen["$key"]="$val"
done < "$ENV_FILE"

for req in APP_ENV PORT DB_POOL LOG_LEVEL; do
  [ -n "${seen[$req]:-}" ] || fail "config/report-api.env missing required key: $req."
done

[ "${seen[PORT]}" = "8080" ] || fail "config/report-api.env PORT must equal '8080' (found: '${seen[PORT]}')."
[ "${seen[APP_ENV]}" = "production" ] || fail "config/report-api.env APP_ENV must equal 'production'."
[ "${seen[DB_POOL]}" = "10" ] || fail "config/report-api.env DB_POOL must equal '10'."
[ "${seen[LOG_LEVEL]}" = "INFO" ] || fail "config/report-api.env LOG_LEVEL must equal 'INFO'."
