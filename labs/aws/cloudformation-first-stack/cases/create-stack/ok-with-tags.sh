aws cloudformation create-stack --stack-name app --template-body file://stack.json --tags Key=lab,Value=cloudformation
for _ in $(seq 1 15); do [ "$(aws cloudformation describe-stacks --stack-name app --query 'Stacks[0].StackStatus' --output text)" = CREATE_COMPLETE ] && break; sleep 1; done
