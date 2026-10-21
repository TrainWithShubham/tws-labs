. "$LAB_LIB"
aws_ready
b="tws-labs-$(aws_account)-cli"
if out=$(aws s3api head-bucket --bucket "$b" 2>&1); then fail "The bucket $b still exists. Delete it."; fi
case "$out" in
  *404*|*"Not Found"*|*NoSuchBucket*) ;;
  *) fail "Could not confirm the bucket is gone (AWS said: ${out##*: }). Check your credentials and try again." ;;
esac
ran_re '(delete-bucket|s3[[:space:]]+rb)([[:space:]]|$)' || fail "The bucket is gone, but you did not delete it in this session. Delete it with the CLI, as the task says."
