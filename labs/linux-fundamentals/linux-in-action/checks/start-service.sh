. "$LAB_LIB"

ran_re '(^|[;&|(][[:space:]]*)(\./start\.sh|bash[[:space:]]+start\.sh)' ||
  fail "Run ./start.sh to launch the service daemon."

[ -f payment.pid ] || fail "payment.pid does not exist. Run ./start.sh to launch the service."

pid=$(awk '{print $1}' payment.pid 2>/dev/null)
start_tick=$(awk '{print $2}' payment.pid 2>/dev/null)

[ -n "$pid" ] && [ "$pid" -eq "$pid" ] 2>/dev/null && [ "$pid" -gt 0 ] 2>/dev/null ||
  fail "payment.pid does not contain a valid numeric PID."

[ -n "$start_tick" ] && [ "$start_tick" -eq "$start_tick" ] 2>/dev/null && [ "$start_tick" -gt 0 ] 2>/dev/null ||
  fail "payment.pid does not contain a valid start-time tick."

[ -d "/proc/$pid" ] || fail "No process with PID $pid is running. Launch the service with ./start.sh."

owner=$(stat -c %u "/proc/$pid" 2>/dev/null || true)
[ "$owner" = "$UID" ] || fail "Process PID $pid belongs to another user (UID $owner, expected $UID)."

stat=$(ps -p "$pid" -o stat= 2>/dev/null | cut -c 1)
[ "$stat" != "Z" ] || fail "payment-service (PID $pid) is in a zombie state."

comm=$(cat "/proc/$pid/comm" 2>/dev/null || true)
[ "$comm" = "payment-service" ] || fail "Process PID $pid is not payment-service (found command: '$comm')."

proc_stat=$(cat "/proc/$pid/stat" 2>/dev/null || true)
actual_tick=$(echo "${proc_stat##*) }" | awk '{print $20}')
[ "$actual_tick" = "$start_tick" ] || fail "Process start-time ($actual_tick) does not match payment.pid ($start_tick)."
