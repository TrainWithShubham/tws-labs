aws dynamodb put-item --table-name orders --item '{"customer":{"S":"alice"},"orderId":{"S":"o-1"},"status":{"S":"PLACED"}}'
