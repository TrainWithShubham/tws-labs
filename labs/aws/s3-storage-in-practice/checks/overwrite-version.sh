. "$LAB_LIB"
emulator_ready
b=tws-labs-notes
aws s3api head-bucket --bucket "$b" >/dev/null 2>&1 || fail "There is no bucket named $b yet. Make it first."
n=$(aws s3api list-object-versions --bucket "$b" --prefix reports/2026-q1.csv --query 'length(Versions[?Key==`reports/2026-q1.csv`])' --output text 2>/dev/null)
[ "${n:-0}" -ge 2 ] 2>/dev/null || fail "reports/2026-q1.csv has ${n:-0} version(s) so far. Upload the corrected file to that same key, with versioning on, to make a second."
size=$(aws s3api head-object --bucket "$b" --key reports/2026-q1.csv --query ContentLength --output text 2>/dev/null)
[ "$size" = "$(wc -c < "$HOME/reports/2026-q1-corrected.csv" | tr -d ' ')" ] || fail "The current reports/2026-q1.csv is not the corrected file yet."
