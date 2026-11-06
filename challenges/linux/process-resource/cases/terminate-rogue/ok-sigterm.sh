ROGUE_PID=$(cat "$HOME/incident/run/rogue-worker.pid")
CHILD_PID=$(cat "$HOME/incident/run/rogue-child.pid")
kill -TERM "$ROGUE_PID" "$CHILD_PID"
