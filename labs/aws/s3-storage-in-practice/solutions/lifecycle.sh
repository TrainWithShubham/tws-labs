printf '%s\n' '{"Rules":[{"ID":"expire-tmp","Status":"Enabled","Filter":{"Prefix":"tmp/"},"Expiration":{"Days":7}}]}' > lifecycle.json
aws s3api put-bucket-lifecycle-configuration --bucket tws-labs-notes --lifecycle-configuration file://lifecycle.json
