#!/bin/bash
set -euo pipefail

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || exit 1
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-050/incident" 2>/dev/null)" || exit 1

# Reset Task 1
rm -f "$INCIDENT_ROOT/reports/discovery.env"
