. "$LAB_LIB"
emulator_ready
stat() { aws cloudformation describe-stacks --stack-name app --query "Stacks[0].StackStatus" --output text 2>/dev/null; }
[ "$(stat)" != "" ] || fail "There is no stack named app."
[ -f bucket.txt ] || fail "No bucket.txt in your home folder yet."
want=$(aws cloudformation describe-stacks --stack-name app --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue | [0]" --output text 2>/dev/null)
[ "$(tr -d '[:space:]' < bucket.txt)" = "$want" ] || fail "bucket.txt should hold only the value of the stack's BucketName output."
ran_re 'cloudformation[[:space:]]+describe-stack' || fail "The value is right, but the task asks you to read it from the stack with the CLI."
