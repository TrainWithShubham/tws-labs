. "$LAB_LIB"

[ -f mount-audit/.mount-audit.passed ] || fail "Run ./mount-audit/verify-mounts to complete validation."
grep -q '"status": "PASSED"' mount-audit/.mount-audit.passed || fail "Mount audit did not pass."
