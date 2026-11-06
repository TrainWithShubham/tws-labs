. "$LAB_LIB"

[ -f proc-incident/config/worker.conf ] || fail "proc-incident/config/worker.conf is missing."
grep -Eq "^SPIN_INTERVAL=5$" proc-incident/config/worker.conf || fail "SPIN_INTERVAL must be 5 in proc-incident/config/worker.conf."
grep -Eq "^MAX_ITERATIONS=100$" proc-incident/config/worker.conf || fail "MAX_ITERATIONS must be 100 in proc-incident/config/worker.conf."
