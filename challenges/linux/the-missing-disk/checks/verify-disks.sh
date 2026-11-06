. "$LAB_LIB"

[ -f disks-incident/.disk-audit.passed ] || fail "Run ./disks-incident/verify-disks to finalize validation."
grep -q '"status": "PASSED"' disks-incident/.disk-audit.passed || fail "Disk audit did not pass."
