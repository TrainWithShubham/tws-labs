aws s3api get-bucket-versioning --bucket "tws-labs-$(aws sts get-caller-identity --query Account --output text)-cli" --query Status --output text > status.txt
