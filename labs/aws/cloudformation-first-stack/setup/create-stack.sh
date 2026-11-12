#!/bin/bash
set -e
# Skipped ahead: make what the earlier tasks would have left, so this task can be done on its own.
cd "$HOME"
[ -f stack.json ] && grep -q 'AWS::SQS::Queue' stack.json || printf '%s\n' '{"Resources":{"Bucket":{"Type":"AWS::S3::Bucket"},"Jobs":{"Type":"AWS::SQS::Queue","Properties":{"QueueName":"jobs"}}},"Outputs":{"BucketName":{"Value":{"Ref":"Bucket"}},"QueueArn":{"Value":{"Fn::GetAtt":["Jobs","Arn"]}}}}' > stack.json
