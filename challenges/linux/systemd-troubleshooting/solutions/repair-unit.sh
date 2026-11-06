#!/bin/bash
set -euo pipefail

BASE_HOME="${LAB_HOME:-$HOME}"
[ -n "$BASE_HOME" ] && [ -d "$BASE_HOME" ] || exit 1
INCIDENT_ROOT="$(realpath -e "$BASE_HOME/lnx-ch-040/incident" 2>/dev/null)" || exit 1

sed -i 's/^Restart=no/Restart=on-failure/' "$INCIDENT_ROOT/systemd/system/report-api.service"
sed -i 's/^PORT=80/PORT=8080/' "$INCIDENT_ROOT/config/report-api.env"
