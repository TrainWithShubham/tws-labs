#!/bin/bash
set -euo pipefail

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || exit 1
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-050/incident" 2>/dev/null)" || exit 1

(
  cd "$INCIDENT_ROOT"
  ./bin/ip route add default via 10.0.1.1 dev eth0
)
