aws dynamodb query --table-name orders --select COUNT --key-condition-expression 'customer = :c' --expression-attribute-values '{":c":{"S":"alice"}}' --query Count --output text > alice-orders.txt
