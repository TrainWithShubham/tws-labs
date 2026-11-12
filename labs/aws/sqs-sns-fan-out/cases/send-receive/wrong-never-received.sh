URL=$(aws sqs get-queue-url --queue-name orders --query QueueUrl --output text)
aws sqs send-message --queue-url "$URL" --message-body order-1001
