ROGUE_PID=$(cat "$HOME/incident/run/rogue-worker.pid")
PARENT_PID=$(cat "$HOME/incident/run/supervisor.pid")
printf 'ROGUE_PID="%s"\nPARENT_PID="%s"\nROGUE_QUEUE="reports"\n' "$ROGUE_PID" "$PARENT_PID" > "$HOME/incident/reports/triage.env"
