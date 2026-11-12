aws cloudformation delete-stack --stack-name app
for _ in $(seq 1 15); do aws cloudformation describe-stacks --stack-name app >/dev/null 2>&1 || break; sleep 1; done
