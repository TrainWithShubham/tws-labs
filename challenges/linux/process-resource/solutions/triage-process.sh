BASE="${LAB_HOME:-$HOME}"
ROGUE_PID=$(cat "$BASE/incident/run/rogue-worker.pid")
PARENT_PID=$(cat "$BASE/incident/run/supervisor.pid")
printf 'ROGUE_PID=%s\nPARENT_PID=%s\nROGUE_QUEUE=reports\n' "$ROGUE_PID" "$PARENT_PID" > "$BASE/incident/reports/triage.env"
