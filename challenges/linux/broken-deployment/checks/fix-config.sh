. "$LAB_LIB"

[ -f deploy/config/app.env ] || fail "deploy/config/app.env is missing."

declare -A seen=()

while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue

  if [[ "$line" =~ ^[^=]*[[:space:]]+= ]] || [[ "$line" =~ =[[:space:]]+ ]]; then
    fail "deploy/config/app.env contains whitespace around '='."
  fi

  if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    fail "deploy/config/app.env contains malformed assignment."
  fi

  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"

  if [[ "$val" =~ ^\" && ! "$val" =~ \"$ ]] || [[ "$val" =~ ^\' && ! "$val" =~ \'$ ]]; then
    fail "deploy/config/app.env contains unclosed quotation."
  fi

  clean_val="$val"
  if [[ "$clean_val" =~ ^\"(.*)\"$ ]] || [[ "$clean_val" =~ ^\'(.*)\'$ ]]; then
    clean_val="${BASH_REMATCH[1]}"
  fi

  if [[ -n "${seen[$key]}" ]]; then
    fail "deploy/config/app.env contains duplicate key: $key."
  fi
  seen["$key"]="$clean_val"
done < deploy/config/app.env

for req in APP_NAME APP_ENV APP_PORT DB_TIMEOUT; do
  [ -n "${seen[$req]}" ] || fail "deploy/config/app.env is missing required key $req."
done

[ "${seen[APP_NAME]}" = "payment-gateway" ] || fail "APP_NAME must be payment-gateway."
[ "${seen[APP_ENV]}" = "production" ] || fail "APP_ENV must be production."
[ "${seen[APP_PORT]}" = "8080" ] || fail "APP_PORT must be 8080."
[ "${seen[DB_TIMEOUT]}" = "30" ] || fail "DB_TIMEOUT must be 30."
