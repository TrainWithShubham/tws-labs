aws s3api put-bucket-versioning --bucket "tws-labs-$(aws sts get-caller-identity --query Account --output text)-cli" --versioning-configuration Status=Enabled
