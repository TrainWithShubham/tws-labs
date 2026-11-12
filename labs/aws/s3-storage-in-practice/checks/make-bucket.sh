. "$LAB_LIB"
emulator_ready
b=tws-labs-notes
aws s3api head-bucket --bucket "$b" >/dev/null 2>&1 || fail "No bucket named $b yet. The name is exactly tws-labs-notes."
