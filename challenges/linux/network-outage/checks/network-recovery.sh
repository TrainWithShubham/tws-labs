#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-050/incident" 2>/dev/null)" || fail "Directory ~/lnx-ch-050/incident does not exist."

ROUTES="$INCIDENT_ROOT/run/net/routes.state"
[ -f "$ROUTES" ] || ROUTES="$INCIDENT_ROOT/config/routes.conf"
[ -f "$ROUTES" ] || fail "Routing configuration not found."

# Verify that route to services subnet via gateway 10.0.1.1 exists on eth0
has_valid_route=false
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  if echo "$line" | grep -Eq "^[[:space:]]*(default|0\.0\.0\.0/0|10\.0\.2\.0/24|10\.0\.2\.100(/32)?)[[:space:]]+via[[:space:]]+10\.0\.1\.1([[:space:]]|$)"; then
    if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+"; then
      if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+eth0([[:space:]]|$)"; then
        has_valid_route=true
      fi
    else
      has_valid_route=true
    fi
  fi
done < "$ROUTES"

[ "$has_valid_route" = "true" ] || fail "Routing table must contain a route forwarding 10.0.2.0/24 (or default) via gateway 10.0.1.1 on interface eth0."
