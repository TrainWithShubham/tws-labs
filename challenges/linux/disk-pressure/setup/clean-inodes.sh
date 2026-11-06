#!/bin/bash
set -euo pipefail

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || exit 1
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/incident" 2>/dev/null)" || exit 1

mkdir -p "$INCIDENT_ROOT/var/cache"
COUNT=$(find "$INCIDENT_ROOT/var/cache" -maxdepth 1 -type f 2>/dev/null | wc -l)
if [ "$COUNT" -lt 500 ]; then
  for i in $(seq -w 1 2500); do
    : > "$INCIDENT_ROOT/var/cache/sess_${i}.tmp"
  done
fi
