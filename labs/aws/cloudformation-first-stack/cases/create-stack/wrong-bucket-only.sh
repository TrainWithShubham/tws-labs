aws cloudformation create-stack --stack-name app --template-body '{"Resources":{"Bucket":{"Type":"AWS::S3::Bucket"}},"Outputs":{"BucketName":{"Value":{"Ref":"Bucket"}}}}'
for _ in $(seq 1 15); do [ "$(aws cloudformation describe-stacks --stack-name app --query 'Stacks[0].StackStatus' --output text)" = CREATE_COMPLETE ] && break; sleep 1; done
