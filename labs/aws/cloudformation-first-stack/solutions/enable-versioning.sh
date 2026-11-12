printf '%s\n' '{"Resources":{"Bucket":{"Type":"AWS::S3::Bucket","Properties":{"VersioningConfiguration":{"Status":"Enabled"}}},"Jobs":{"Type":"AWS::SQS::Queue","Properties":{"QueueName":"jobs"}}},"Outputs":{"BucketName":{"Value":{"Ref":"Bucket"}},"QueueArn":{"Value":{"Fn::GetAtt":["Jobs","Arn"]}}}}' > stack.json
aws cloudformation update-stack --stack-name app --template-body file://stack.json
for _ in $(seq 1 15); do [ "$(aws cloudformation describe-stacks --stack-name app --query 'Stacks[0].StackStatus' --output text)" = UPDATE_COMPLETE ] && break; sleep 1; done
