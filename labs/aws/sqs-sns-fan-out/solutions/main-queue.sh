DLQ=$(aws sqs get-queue-url --queue-name orders-dlq --query QueueUrl --output text)
ARN=$(aws sqs get-queue-attributes --queue-url "$DLQ" --attribute-names QueueArn --query Attributes.QueueArn --output text)
printf '{"RedrivePolicy":"{\\"deadLetterTargetArn\\":\\"%s\\",\\"maxReceiveCount\\":\\"3\\"}"}\n' "$ARN" > attrs.json
aws sqs create-queue --queue-name orders --attributes file://attrs.json
