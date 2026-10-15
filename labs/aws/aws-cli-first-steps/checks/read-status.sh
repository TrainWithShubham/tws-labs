. "$LAB_LIB"
aws_ready
ran_re 'aws[[:space:]]+s3api[[:space:]]+get-bucket-versioning' || fail "Read the setting with the get operation for bucket versioning."
ran_re '[[:space:]]--query([[:space:]=]|$)' || fail "Use --query to pick out just the status."
[ -s status.txt ] || fail "Save the answer in status.txt."
[ "$(tr -d '[:space:]' < status.txt)" = "Enabled" ] || fail "status.txt should hold just the word Enabled (no JSON, no quotes). Use --query and --output text."
[ "$(wc -w < status.txt | tr -d ' ')" = "1" ] || fail "status.txt should hold only the status word."
