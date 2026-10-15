. "$LAB_LIB"
aws_ready
b="tws-labs-$(aws_account)-cli"
tags=$(aws s3api get-bucket-tagging --bucket "$b" --query 'TagSet' --output json 2>/dev/null) || fail "Bucket $b has no tags yet (or does not exist)."
ok=$(printf '%s' "$tags" | node -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>{try{const t=JSON.parse(s);console.log(t.some(x=>x.Key==="tws-labs"&&x.Value==="aws-cli-first-steps"))}catch{console.log(false)}})')
[ "$ok" = "true" ] || fail "Add the tag Key=tws-labs, Value=aws-cli-first-steps to the bucket."
