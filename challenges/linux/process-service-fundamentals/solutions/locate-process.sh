pid=$(pgrep -f "proc-incident/bin/spin-worker" | head -n1)
echo "$pid" > proc-incident/reports/rogue-pid.txt
