TOPIC=$(aws sns list-topics --query "Topics[?ends_with(TopicArn, ':order-events')].TopicArn | [0]" --output text)
QURL=$(aws sqs get-queue-url --queue-name orders --query QueueUrl --output text)
QARN=$(aws sqs get-queue-attributes --queue-url "$QURL" --attribute-names QueueArn --query Attributes.QueueArn --output text)
printf '{"Policy":"{\\"Version\\":\\"2012-10-17\\",\\"Statement\\":[{\\"Effect\\":\\"Allow\\",\\"Principal\\":{\\"Service\\":\\"sns.amazonaws.com\\"},\\"Action\\":\\"sqs:SendMessage\\",\\"Resource\\":\\"%s\\",\\"Condition\\":{\\"ArnEquals\\":{\\"aws:SourceArn\\":\\"%s\\"}}}]}"}\n' "$QARN" "$TOPIC" > policy.json
aws sqs set-queue-attributes --queue-url "$QURL" --attributes file://policy.json
