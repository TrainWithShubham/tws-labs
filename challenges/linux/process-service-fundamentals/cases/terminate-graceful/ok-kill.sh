pid=$(cat proc-incident/run/worker.pid 2>/dev/null || pgrep -f "proc-incident/bin/spin-worker" | head -n1)
if [ -n "$pid" ]; then
  kill "$pid" 2>/dev/null || true
  sleep 0.5
fi
