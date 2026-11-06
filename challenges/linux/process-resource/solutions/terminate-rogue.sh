BASE="${LAB_HOME:-$HOME}"
ROGUE_PID=$(cat "$BASE/incident/run/rogue-worker.pid")
CHILD_PID=$(cat "$BASE/incident/run/rogue-child.pid")
kill -TERM "$ROGUE_PID" "$CHILD_PID" 2>/dev/null || kill -9 "$ROGUE_PID" "$CHILD_PID" 2>/dev/null || true
