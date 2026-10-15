aws s3api delete-bucket --bucket "tws-labs-$(aws sts get-caller-identity --query Account --output text)-cli"
