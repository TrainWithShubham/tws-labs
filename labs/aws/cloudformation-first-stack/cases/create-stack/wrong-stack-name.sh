aws cloudformation create-stack --stack-name application --template-body file://stack.json
for _ in $(seq 1 15); do [ "$(aws cloudformation describe-stacks --stack-name application --query 'Stacks[0].StackStatus' --output text)" = CREATE_COMPLETE ] && break; sleep 1; done
