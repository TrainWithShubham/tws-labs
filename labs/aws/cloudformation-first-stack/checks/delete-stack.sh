. "$LAB_LIB"
emulator_ready
ran_re 'cloudformation[[:space:]]+delete-stack' || fail "Delete the stack with aws cloudformation delete-stack."
gone() { ! aws cloudformation describe-stacks --stack-name app >/dev/null 2>&1; }
retry 15 1 gone || fail "The stack app still exists (give it a moment, or wait with aws cloudformation wait stack-delete-complete)."
! aws sqs get-queue-url --queue-name jobs >/dev/null 2>&1 || fail "The stack is gone, but its queue jobs is still there."
