#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-050/incident" 2>/dev/null)" || fail "Directory ~/lnx-ch-050/incident does not exist."

MARKER="$INCIDENT_ROOT/reports/audit-success.marker"
[ -f "$MARKER" ] || fail "reports/audit-success.marker not found. Run ./bin/network-audit."

grep -Fxq "NETWORK_STATUS=RECOVERED" "$MARKER" || fail "Audit marker missing NETWORK_STATUS=RECOVERED."
grep -Fxq "CLIENT_IP=10.0.1.10" "$MARKER" || fail "Audit marker missing CLIENT_IP=10.0.1.10."
grep -Fxq "ACTIVE_GATEWAY=10.0.1.1" "$MARKER" || fail "Audit marker missing ACTIVE_GATEWAY=10.0.1.1."
grep -Fxq "TARGET_REACHABLE=10.0.2.100" "$MARKER" || fail "Audit marker missing TARGET_REACHABLE=10.0.2.100."
grep -Fxq "DNS_RESOLVED=api.internal.corp" "$MARKER" || fail "Audit marker missing DNS_RESOLVED=api.internal.corp."
grep -Fxq "AUDITED_BY=netops_audit_v1" "$MARKER" || fail "Audit marker missing AUDITED_BY=netops_audit_v1."

# Independent verification of underlying state
ROUTES="$INCIDENT_ROOT/run/net/routes.state"
[ -f "$ROUTES" ] || ROUTES="$INCIDENT_ROOT/config/routes.conf"
[ -f "$ROUTES" ] || fail "Independent check failed: routing table configuration is missing."

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

[ "$has_valid_route" = "true" ] || fail "Independent check failed: missing active route to 10.0.2.0/24 via 10.0.1.1 on interface eth0."

[ -f "$INCIDENT_ROOT/config/resolv.conf" ] || fail "Independent check failed: resolv.conf missing."
grep -Eq "^[[:space:]]*nameserver[[:space:]]+10\.0\.2\.53([[:space:]]|$)" "$INCIDENT_ROOT/config/resolv.conf" || fail "Independent check failed: DNS resolver not configured to 10.0.2.53."
