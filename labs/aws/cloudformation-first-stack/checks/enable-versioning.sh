. "$LAB_LIB"
emulator_ready
stat() { aws cloudformation describe-stacks --stack-name app --query "Stacks[0].StackStatus" --output text 2>/dev/null; }
retry 15 1 sh -c '[ "$(aws cloudformation describe-stacks --stack-name app --query "Stacks[0].StackStatus" --output text 2>/dev/null)" = UPDATE_COMPLETE ]' || fail "The stack has not been updated yet (its status is: $(stat | sed 's/^$/not found/')). Change the template, then update the stack."
b=$(aws cloudformation describe-stacks --stack-name app --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue | [0]" --output text 2>/dev/null)
[ "$(aws s3api get-bucket-versioning --bucket "$b" --query Status --output text 2>/dev/null)" = Enabled ] || fail "The stack was updated, but the bucket does not have versioning enabled. Add VersioningConfiguration to the bucket in the template."
ran_re 'cloudformation[[:space:]]+(update-stack|execute-change-set)' || fail "Versioning is on, but the task asks you to apply it through the stack (update-stack or a change set)."
