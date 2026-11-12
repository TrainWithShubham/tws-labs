B=$(aws cloudformation describe-stacks --stack-name app --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" --output text)
aws s3api put-bucket-versioning --bucket "$B" --versioning-configuration Status=Enabled
