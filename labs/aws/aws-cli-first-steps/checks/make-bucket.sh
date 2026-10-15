. "$LAB_LIB"
aws_ready
aws_region_is us-east-1 || fail "This lab uses us-east-1. Set AWS_REGION=us-east-1 and restart the labs (docs/aws-labs.md)."
b="tws-labs-$(aws_account)-cli"
retry 5 2 aws s3api head-bucket --bucket "$b" >/dev/null 2>&1 || fail "No bucket named $b yet. The name is tws-labs-<your account id>-cli."
