#!/bin/bash
set -u

fail() { echo "$*"; exit 1; }

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || fail "Home directory not found."
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/incident" 2>/dev/null)" || fail "Directory ~/incident does not exist."

CACHE_DIR="$INCIDENT_ROOT/var/cache"
[ -d "$CACHE_DIR" ] || fail "Directory incident/var/cache is missing."
COUNT=$(find "$CACHE_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
[ "$COUNT" -le 50 ] || fail "incident/var/cache still contains $COUNT files (must be 50 or fewer)."
