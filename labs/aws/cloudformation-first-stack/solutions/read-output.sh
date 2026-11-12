aws cloudformation describe-stacks --stack-name app --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" --output text > bucket.txt
