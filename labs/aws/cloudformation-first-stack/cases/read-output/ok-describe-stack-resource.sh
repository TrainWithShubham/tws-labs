aws cloudformation describe-stack-resource --stack-name app --logical-resource-id Bucket --query StackResourceDetail.PhysicalResourceId --output text > bucket.txt
