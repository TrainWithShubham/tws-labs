ROGUE_PID=$(cat "$HOME/incident/run/rogue-worker.pid")
kill -9 "$ROGUE_PID"
