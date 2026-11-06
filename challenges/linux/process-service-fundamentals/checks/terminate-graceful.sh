. "$LAB_LIB"

if pgrep -f "proc-incident/bin/spin-worker" >/dev/null 2>&1; then
  fail "spin-worker is still running. Send SIGTERM with kill <pid>."
fi
[ -f proc-incident/run/worker.status ] || fail "run/worker.status was not found. Ensure SIGTERM was sent."
grep -q "CLEAN_SHUTDOWN" proc-incident/run/worker.status || fail "worker did not shut down cleanly."
