aws s3api put-bucket-tagging --bucket "tws-labs-$(aws sts get-caller-identity --query Account --output text)-cli" --tagging 'TagSet=[{Key=tws-labs,Value=aws-cli-first-steps}]'
