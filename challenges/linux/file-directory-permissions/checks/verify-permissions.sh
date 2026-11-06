. "$LAB_LIB"

[ -f deploy/.permissions-audit.passed ] || fail "Run ./deploy/verify-permissions to complete validation."
grep -q '"status": "PASSED"' deploy/.permissions-audit.passed || fail "Permissions audit did not pass."
