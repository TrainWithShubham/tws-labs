#!/bin/bash
set -e
# Skipped ahead: make the orders table (and what the earlier tasks would have put in it) so this task can be done on its own.
ensure_table() {
  aws dynamodb describe-table --table-name orders >/dev/null 2>&1 ||
    aws dynamodb create-table --table-name orders --attribute-definitions AttributeName=customer,AttributeType=S AttributeName=orderId,AttributeType=S --key-schema AttributeName=customer,KeyType=HASH AttributeName=orderId,KeyType=RANGE --billing-mode PAY_PER_REQUEST >/dev/null
  for _ in $(seq 1 10); do [ "$(aws dynamodb describe-table --table-name orders --query Table.TableStatus --output text 2>/dev/null)" = ACTIVE ] && break; sleep 1; done
}
ensure_table
[ "$(aws dynamodb scan --table-name orders --select COUNT --query Count --output text)" != 0 ] || aws dynamodb batch-write-item --request-items file://"$HOME"/orders.json >/dev/null
