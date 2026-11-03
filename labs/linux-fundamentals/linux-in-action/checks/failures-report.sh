. "$LAB_LIB"

[ -f logs/service.log ] || fail "logs/service.log does not exist."
[ -f reports/failures.txt ] || fail "reports/failures.txt does not exist."
[ -s reports/failures.txt ] || fail "reports/failures.txt is empty."

expected_lines=$(awk '$9 == 500' .fixtures/service.log | wc -l)
actual_lines=$(wc -l < reports/failures.txt | tr -d '[:space:]')
[ "$actual_lines" -eq "$expected_lines" ] || fail "Expected $expected_lines entries in reports/failures.txt, found $actual_lines."

cmp -s reports/failures.txt <(awk '$9 == 500 {print $1, $7}' .fixtures/service.log) ||
  fail "reports/failures.txt content does not match expected timestamp and path columns."
