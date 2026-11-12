#!/bin/bash
set -e
# Skipped ahead: make what the earlier tasks would have left, so this task can be done on its own.
aws sqs get-queue-url --queue-name orders-dlq >/dev/null 2>&1 || aws sqs create-queue --queue-name orders-dlq >/dev/null
