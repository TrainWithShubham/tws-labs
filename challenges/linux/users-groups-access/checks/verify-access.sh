. "$LAB_LIB"

[ -f access/.access-audit.passed ] || fail "Run ./access/verify-access to complete validation."
grep -q '"status": "PASSED"' access/.access-audit.passed || fail "Access audit did not pass."
