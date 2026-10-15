. "$LAB_LIB"

if [ -f .runaway.pid ]; then
  pid=$(cat .runaway.pid 2>/dev/null)
  if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
    fail "The runaway-worker process (PID $pid) is still running."
  fi
fi

if pgrep -f runaway-worker >/dev/null 2>&1 || pgrep runaway-worker >/dev/null 2>&1; then
  fail "The runaway-worker process is still running."
fi
