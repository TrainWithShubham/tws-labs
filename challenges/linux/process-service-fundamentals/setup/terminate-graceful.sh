#!/bin/bash
set -euo pipefail
if ! pgrep -f "proc-incident/bin/spin-worker" >/dev/null 2>&1; then
  nohup "$HOME/proc-incident/bin/spin-worker" >/dev/null 2>&1 &
  sleep 0.2
fi
pid=$(cat "$HOME/proc-incident/run/worker.pid" 2>/dev/null || pgrep -f "proc-incident/bin/spin-worker" | head -n1)
echo "$pid" > "$HOME/proc-incident/reports/rogue-pid.txt"
rm -f "$HOME/proc-incident/run/worker.status"
