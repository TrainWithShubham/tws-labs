CHILD_PID=$(cat "$HOME/incident/run/rogue-child.pid")
printf 'CHILD_PID="%s"\nBATCH_ID="9021"\nWORKER_NAME="report-worker"\n' "$CHILD_PID" >> "$HOME/incident/reports/triage.env"
