#!/bin/bash
set -e
# Skipped ahead: make what the earlier tasks would have left, so this task can be done on its own.
cd "$HOME"
[ -f stack.json ] && grep -q 'AWS::SQS::Queue' stack.json || printf '%s\n' '{"Resources":{"Bucket":{"Type":"AWS::S3::Bucket"},"Jobs":{"Type":"AWS::SQS::Queue","Properties":{"QueueName":"jobs"}}},"Outputs":{"BucketName":{"Value":{"Ref":"Bucket"}},"QueueArn":{"Value":{"Fn::GetAtt":["Jobs","Arn"]}}}}' > stack.json
aws cloudformation describe-stacks --stack-name app >/dev/null 2>&1 || {
  aws cloudformation create-stack --stack-name app --template-body file://"$HOME"/stack.json >/dev/null
  for _ in $(seq 1 15); do [ "$(aws cloudformation describe-stacks --stack-name app --query 'Stacks[0].StackStatus' --output text)" = CREATE_COMPLETE ] && break; sleep 1; done
}
