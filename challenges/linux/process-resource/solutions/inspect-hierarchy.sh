BASE="${LAB_HOME:-$HOME}"
CHILD_PID=$(cat "$BASE/incident/run/rogue-child.pid")
printf 'CHILD_PID=%s\nBATCH_ID=9021\nWORKER_NAME=report-worker\n' "$CHILD_PID" >> "$BASE/incident/reports/triage.env"
