. "$LAB_LIB"
emulator_ready
stat() { aws cloudformation describe-stacks --stack-name app --query "Stacks[0].StackStatus" --output text 2>/dev/null; }
ran_re 'cloudformation[[:space:]]+create-stack' || fail "Create the stack with aws cloudformation create-stack."
done_() { case "$(stat)" in CREATE_COMPLETE|UPDATE_COMPLETE) return 0;; *) return 1;; esac; }
retry 15 1 done_ || fail "There is no finished stack named app yet (its status is: $(stat | sed 's/^$/not found/'))."
q=$(aws cloudformation list-stack-resources --stack-name app --query "StackResourceSummaries[?ResourceType=='AWS::SQS::Queue'].LogicalResourceId | [0]" --output text 2>/dev/null)
{ [ -n "$q" ] && [ "$q" != None ]; } || fail "The stack exists, but it has no queue: it was made from a template without one. Add the queue to stack.json first."
