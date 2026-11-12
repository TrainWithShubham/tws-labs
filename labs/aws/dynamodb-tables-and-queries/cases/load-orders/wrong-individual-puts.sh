aws dynamodb put-item --table-name orders --item '{"customer":{"S":"alice"},"orderId":{"S":"o-1"},"status":{"S":"PLACED"}}'
aws dynamodb put-item --table-name orders --item '{"customer":{"S":"alice"},"orderId":{"S":"o-2"},"status":{"S":"PLACED"}}'
aws dynamodb put-item --table-name orders --item '{"customer":{"S":"bob"},"orderId":{"S":"o-3"},"status":{"S":"PLACED"}}'
