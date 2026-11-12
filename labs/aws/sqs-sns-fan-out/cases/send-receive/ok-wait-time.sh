URL=$(aws sqs get-queue-url --queue-name orders --query QueueUrl --output text)
aws sqs send-message --queue-url "$URL" --message-body order-1001
HANDLE=$(aws sqs receive-message --queue-url "$URL" --max-number-of-messages 1 --wait-time-seconds 1 --query 'Messages[0].ReceiptHandle' --output text)
aws sqs delete-message --queue-url "$URL" --receipt-handle "$HANDLE"
