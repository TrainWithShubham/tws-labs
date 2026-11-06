SUPER_PID=$(cat "$HOME/incident/run/supervisor.pid")
ROGUE_PID=$(cat "$HOME/incident/run/rogue-worker.pid")
CHILD_PID=$(cat "$HOME/incident/run/rogue-child.pid")
kill -9 "$SUPER_PID" "$ROGUE_PID" "$CHILD_PID"
