. "$LAB_LIB"

[ -f bin/check-service ] || fail "bin/check-service does not exist."
[ -x bin/check-service ] || fail "bin/check-service must be executable (run: chmod +x bin/check-service)."

# Verify function declaration (stripping comment lines)
grep -v '^[[:space:]]*#' bin/check-service | grep -Eq '^[[:space:]]*(function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*|[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\))' ||
  fail "bin/check-service should define and use a shell function."

# Test 1: Zero arguments -> exit 1, empty stdout, usage on stderr
stdout=$(bin/check-service 2>/dev/null)
code=$?
stderr=$(bin/check-service 2>&1 >/dev/null)
[ "$code" -eq 1 ] || fail "bin/check-service should exit with status 1 when arguments are missing (got $code)."
[ -z "$stdout" ] || fail "bin/check-service should not output to stdout when arguments are missing (got: '$stdout')."
echo "$stderr" | grep -Eiq 'usage' || fail "bin/check-service should output usage message to stderr when arguments are missing."

# Test 2: Multiple arguments -> exit 1, empty stdout, usage on stderr
stdout=$(bin/check-service arg1 arg2 2>/dev/null)
code=$?
stderr=$(bin/check-service arg1 arg2 2>&1 >/dev/null)
[ "$code" -eq 1 ] || fail "bin/check-service should exit with status 1 when given multiple arguments (got $code)."
[ -z "$stdout" ] || fail "bin/check-service should not output to stdout when given multiple arguments (got: '$stdout')."
echo "$stderr" | grep -Eiq 'usage' || fail "bin/check-service should output usage message to stderr when given multiple arguments."

# Test 3: Missing file -> exit 2, CONFIG ERROR on stdout, error detail on stderr
stdout=$(bin/check-service nonexistent_config_file.env 2>/dev/null)
code=$?
stderr=$(bin/check-service nonexistent_config_file.env 2>&1 >/dev/null)
[ "$code" -eq 2 ] || fail "bin/check-service should exit with status 2 when config file is missing (got $code)."
[ "$stdout" = "CONFIG ERROR" ] || fail "bin/check-service should print 'CONFIG ERROR' to stdout when config file is missing (got: '$stdout')."
[ -n "$stderr" ] || fail "bin/check-service should output error detail to stderr when config file is missing."

# Test 4: Empty file -> exit 2, CONFIG ERROR on stdout, error detail on stderr
empty_test_file=".fixtures/empty.env"
[ -e "$empty_test_file" ] || empty_test_file="/dev/null"
stdout=$(bin/check-service "$empty_test_file" 2>/dev/null)
code=$?
stderr=$(bin/check-service "$empty_test_file" 2>&1 >/dev/null)
[ "$code" -eq 2 ] || fail "bin/check-service should exit with status 2 when config file is empty (got $code)."
[ "$stdout" = "CONFIG ERROR" ] || fail "bin/check-service should print 'CONFIG ERROR' to stdout when config file is empty (got: '$stdout')."
[ -n "$stderr" ] || fail "bin/check-service should output error detail to stderr when config file is empty."

# Test 5: Valid production config (config/app.env with PORT=8080) -> exit 0, CONFIG OK on stdout, empty stderr
[ -f config/app.env ] || fail "config/app.env does not exist. Complete Task 2 first."
grep -Eq '^PORT=8080$' config/app.env || fail "config/app.env must contain PORT=8080."
! grep -Eq '^PORT=80$' config/app.env || fail "config/app.env still contains PORT=80."
stdout=$(bin/check-service config/app.env 2>/dev/null)
code=$?
stderr=$(bin/check-service config/app.env 2>&1 >/dev/null)
[ "$code" -eq 0 ] || fail "bin/check-service should exit with status 0 for valid config config/app.env (got $code)."
[ "$stdout" = "CONFIG OK" ] || fail "bin/check-service should print 'CONFIG OK' to stdout for valid config (got: '$stdout')."
[ -z "$stderr" ] || fail "bin/check-service should not output to stderr for valid config (got: '$stderr')."
