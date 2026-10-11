. "$LAB_LIB"

[ -f "web-server/debug.log" ] || fail "web-server/debug.log is missing"
cmp -s "web-server/debug.log" ".fixtures/debug.log" || fail "web-server/debug.log was modified: keep the original file intact and redirect output to debug-clean.log"
[ -f "debug-clean.log" ] || fail "debug-clean.log not found in current directory"
[ -s "debug-clean.log" ] || fail "debug-clean.log is empty"

cmp -s "debug-clean.log" <(sed -E 's/api_key=[a-zA-Z0-9]+/api_key=REDACTED/g' .fixtures/debug.log) || fail "debug-clean.log does not match expected sanitized log"

ran sed || fail "Use sed to sanitize sensitive tokens"
ran_re "REDACTED" || fail "Use REDACTED as the replacement token in sed"