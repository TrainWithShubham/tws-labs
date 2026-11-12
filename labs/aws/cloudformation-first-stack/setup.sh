#!/bin/bash
set -e
# Seed the starter template, and start every session from no stack: the emulator keeps its resources until it restarts, and a leftover stack
# (or its queue) would make early tasks look done. Deleting a stack takes a moment, so wait for it to go.
printf '%s\n' '{"Resources":{"Bucket":{"Type":"AWS::S3::Bucket"}},"Outputs":{"BucketName":{"Value":{"Ref":"Bucket"}}}}' > ~/stack.json
if command -v aws >/dev/null 2>&1; then
  # Delete every stack, not only app: a stack under another name that owns the queue jobs would make creating app fail.
  for st in $(aws cloudformation list-stacks --query "StackSummaries[?StackStatus!='DELETE_COMPLETE'].StackName" --output text 2>/dev/null); do
    aws cloudformation delete-stack --stack-name "$st" >/dev/null 2>&1 || true
  done
  for _ in $(seq 1 12); do [ -z "$(aws cloudformation list-stacks --query "StackSummaries[?StackStatus!='DELETE_COMPLETE'].StackName" --output text 2>/dev/null)" ] && break; sleep 1; done
  url=$(aws sqs get-queue-url --queue-name jobs --query QueueUrl --output text 2>/dev/null) && aws sqs delete-queue --queue-url "$url" >/dev/null 2>&1 || true
fi
