#!/bin/bash
set -euo pipefail
rm -f "$HOME/proc-incident/reports/rogue-pid.txt"
if ! pgrep -f "proc-incident/bin/spin-worker" >/dev/null 2>&1; then
  nohup "$HOME/proc-incident/bin/spin-worker" >/dev/null 2>&1 &
  sleep 0.2
fi
