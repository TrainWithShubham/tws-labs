. "$LAB_LIB"

[ -f proc-incident/reports/rogue-pid.txt ] || fail "proc-incident/reports/rogue-pid.txt is missing."
pid=$(tr -d '[:space:]' < proc-incident/reports/rogue-pid.txt)
[ -n "$pid" ] || fail "rogue-pid.txt is empty."
if [ -d "/proc/$pid" ]; then
  cmd=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ')
  echo "$cmd" | grep -q "spin-worker" || fail "PID $pid is not the spin-worker process."
elif [ -f proc-incident/run/worker.pid ]; then
  actual_pid=$(cat proc-incident/run/worker.pid 2>/dev/null || echo "")
  [ "$pid" = "$actual_pid" ] || fail "PID $pid does not match recorded worker PID."
fi
