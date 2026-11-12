TOPIC=$(aws sns create-topic --name events --query TopicArn --output text)
QURL=$(aws sqs get-queue-url --queue-name orders --query QueueUrl --output text)
QARN=$(aws sqs get-queue-attributes --queue-url "$QURL" --attribute-names QueueArn --query Attributes.QueueArn --output text)
aws sns subscribe --topic-arn "$TOPIC" --protocol sqs --notification-endpoint "$QARN"
