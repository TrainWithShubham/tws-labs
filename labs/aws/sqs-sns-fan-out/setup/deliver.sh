#!/bin/bash
set -e
# Skipped ahead: make what the earlier tasks would have left, so this task can be done on its own.
aws sqs get-queue-url --queue-name orders-dlq >/dev/null 2>&1 || aws sqs create-queue --queue-name orders-dlq >/dev/null
if ! aws sqs get-queue-url --queue-name orders >/dev/null 2>&1; then
  dlq=$(aws sqs get-queue-url --queue-name orders-dlq --query QueueUrl --output text)
  arn=$(aws sqs get-queue-attributes --queue-url "$dlq" --attribute-names QueueArn --query Attributes.QueueArn --output text)
  printf '{"RedrivePolicy":"{\\"deadLetterTargetArn\\":\\"%s\\",\\"maxReceiveCount\\":\\"3\\"}"}\n' "$arn" > /tmp/lab-attrs.json
  aws sqs create-queue --queue-name orders --attributes file:///tmp/lab-attrs.json >/dev/null
fi
acct=$(aws sts get-caller-identity --query Account --output text)
topic=$(aws sns create-topic --name order-events --query TopicArn --output text)
q=$(aws sqs get-queue-url --queue-name orders --query QueueUrl --output text)
qarn=$(aws sqs get-queue-attributes --queue-url "$q" --attribute-names QueueArn --query Attributes.QueueArn --output text)
[ -n "$(aws sns list-subscriptions-by-topic --topic-arn "$topic" --query "Subscriptions[?Endpoint=='$qarn'].SubscriptionArn | [0]" --output text | grep -v None)" ] || aws sns subscribe --topic-arn "$topic" --protocol sqs --notification-endpoint "$qarn" >/dev/null
