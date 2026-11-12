. "$LAB_LIB"
emulator_ready
b=tws-labs-notes
aws s3api head-bucket --bucket "$b" >/dev/null 2>&1 || fail "There is no bucket named $b yet. Make it first."
s=$(aws s3api get-bucket-versioning --bucket "$b" --query Status --output text 2>/dev/null)
[ "$s" = Enabled ] || fail "Versioning is not enabled on $b yet (it reads: ${s:-not set})."
