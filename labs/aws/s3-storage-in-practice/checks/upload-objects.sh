. "$LAB_LIB"
emulator_ready
b=tws-labs-notes
aws s3api head-bucket --bucket "$b" >/dev/null 2>&1 || fail "There is no bucket named $b yet. Make it first."
for f in 2026-q1.csv 2026-q2.csv; do
  size=$(aws s3api head-object --bucket "$b" --key "reports/$f" --query ContentLength --output text 2>/dev/null) || fail "reports/$f is not in the bucket yet. The key is the prefix reports/ plus the file name."
  [ "$size" = "$(wc -c < "$HOME/reports/$f" | tr -d ' ')" ] || fail "reports/$f is in the bucket, but its size does not match your local file. Upload it again."
done
