#!/bin/bash
set -euo pipefail
pkill -f "proc-incident/bin/spin-worker" 2>/dev/null || true
echo "CLEAN_SHUTDOWN" > "$HOME/proc-incident/run/worker.status"
rm -f "$HOME/proc-incident/run/worker.pid"
sed -i 's/^SPIN_INTERVAL=.*/SPIN_INTERVAL=0/' "$HOME/proc-incident/config/worker.conf" 2>/dev/null || true
sed -i 's/^MAX_ITERATIONS=.*/MAX_ITERATIONS=-1/' "$HOME/proc-incident/config/worker.conf" 2>/dev/null || true
