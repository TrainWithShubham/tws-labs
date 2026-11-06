. "$LAB_LIB"

[ -f proc-incident/.service-audit.passed ] || fail "Run ./proc-incident/verify-service to finalize validation."
grep -q '"status": "PASSED"' proc-incident/.service-audit.passed || fail "Service audit did not pass."
