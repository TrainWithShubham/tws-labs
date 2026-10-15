. "$LAB_LIB"
aws_ready
b="tws-labs-$(aws_account)-cli"
if aws s3api head-bucket --bucket "$b" >/dev/null 2>&1; then fail "The bucket $b still exists. Delete it."; fi
