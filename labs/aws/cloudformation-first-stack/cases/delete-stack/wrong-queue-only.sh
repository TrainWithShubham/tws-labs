aws sqs delete-queue --queue-url "$(aws sqs get-queue-url --queue-name jobs --query QueueUrl --output text)"
