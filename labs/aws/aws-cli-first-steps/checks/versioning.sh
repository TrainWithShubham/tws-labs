. "$LAB_LIB"
aws_ready
b="tws-labs-$(aws_account)-cli"
[ "$(aws s3api get-bucket-versioning --bucket "$b" --query Status --output text 2>/dev/null)" = "Enabled" ] || fail "Versioning is not enabled on $b yet."
