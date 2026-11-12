aws dynamodb create-table --table-name orders --attribute-definitions AttributeName=customer,AttributeType=S --key-schema AttributeName=customer,KeyType=HASH --billing-mode PAY_PER_REQUEST
