aws s3api create-bucket --bucket "tws-labs-$(aws sts get-caller-identity --query Account --output text)-cli"
