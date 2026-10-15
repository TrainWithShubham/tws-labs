. "$LAB_LIB"
aws_ready
ran_re 'aws[[:space:]]+sts[[:space:]]+get-caller-identity' || fail "Run the AWS command that reports your identity."
[ -s identity.json ] || fail "Save the command's output in identity.json."
[ "$(yaml_get identity.json 'd.Account')" = "$(aws_account)" ] || fail "identity.json does not hold the output of your current identity. Run the command again and redirect it into the file."
