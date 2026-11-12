aws dynamodb query --table-name orders --key-condition-expression 'customer = :c' --expression-attribute-values '{":c":{"S":"bob"}}' --query Count --output text > alice-orders.txt
