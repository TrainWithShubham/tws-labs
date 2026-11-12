printf '%s\n' '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Principal":"*","Action":"s3:*","Resource":["arn:aws:s3:::tws-labs-notes","arn:aws:s3:::tws-labs-notes/*"],"Condition":{"Bool":{"aws:SecureTransport":"true"}}}]}' > policy.json
aws s3api put-bucket-policy --bucket tws-labs-notes --policy file://policy.json
