. "$LAB_LIB"

if [ -f .worker.pid ]; then
  read -r pid start_tick extra < .worker.pid 2>/dev/null || true
  # STRICT PID file validation: reject PID-only, missing-start-time, or extra fields
  if [ -n "$pid" ] && [ -n "$start_tick" ] && [ -z "$extra" ] &&
     [ "$pid" -eq "$pid" ] 2>/dev/null && [ "$pid" -gt 0 ] 2>/dev/null &&
     [ "$start_tick" -eq "$start_tick" ] 2>/dev/null && [ "$start_tick" -gt 0 ] 2>/dev/null; then
    if [ -d "/proc/$pid" ]; then
      owner=$(stat -c %u "/proc/$pid" 2>/dev/null || true)
      comm=$(cat "/proc/$pid/comm" 2>/dev/null || true)
      stat=$(ps -p "$pid" -o stat= 2>/dev/null | cut -c 1)
      proc_stat=$(cat "/proc/$pid/stat" 2>/dev/null || true)
      actual_tick=$(echo "${proc_stat##*) }" | awk '{print $20}')
      if [ "$owner" = "$UID" ] && [ "$comm" = "payment-worker" ] && [ "$stat" != "Z" ] && [ "$actual_tick" = "$start_tick" ]; then
        fail "payment-worker (PID $pid) is still running. Terminate it before proceeding."
      fi
    fi
  fi
fi

if proc_running payment-worker; then
  fail "payment-worker is still running. Terminate it before proceeding."
fi

if [ -e .service.lock ]; then
  fail ".service.lock still exists. Remove the stale lockfile."
fi
