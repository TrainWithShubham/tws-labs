#!/bin/bash
set -e
# Start every session from no queues and no topic: the emulator keeps its resources until it restarts, and leftovers would make early tasks look done.
if command -v aws >/dev/null 2>&1; then
  for q in orders orders-dlq; do
    url=$(aws sqs get-queue-url --queue-name "$q" --query QueueUrl --output text 2>/dev/null) && aws sqs delete-queue --queue-url "$url" >/dev/null 2>&1 || true
  done
  arn=$(aws sns list-topics --query "Topics[?ends_with(TopicArn, ':order-events')].TopicArn | [0]" --output text 2>/dev/null || true)
  if [ -n "$arn" ] && [ "$arn" != None ]; then aws sns delete-topic --topic-arn "$arn" >/dev/null 2>&1 || true; fi
fi
