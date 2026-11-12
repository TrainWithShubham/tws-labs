#!/bin/bash
set -e
# Seed the batch the lab loads, and start every session from no table: the emulator keeps its resources until it restarts, and a leftover
# table would make the first task look done. Deleting a table takes a few seconds, so wait for it to go.
printf '%s\n' '{"orders":[{"PutRequest":{"Item":{"customer":{"S":"alice"},"orderId":{"S":"o-1"},"status":{"S":"PLACED"},"total":{"N":"30"}}}},{"PutRequest":{"Item":{"customer":{"S":"alice"},"orderId":{"S":"o-2"},"status":{"S":"PLACED"},"total":{"N":"12"}}}},{"PutRequest":{"Item":{"customer":{"S":"bob"},"orderId":{"S":"o-3"},"status":{"S":"PLACED"},"total":{"N":"50"}}}}]}' > ~/orders.json
if command -v aws >/dev/null 2>&1 && aws dynamodb describe-table --table-name orders >/dev/null 2>&1; then
  aws dynamodb delete-table --table-name orders >/dev/null 2>&1 || true
  for _ in $(seq 1 12); do aws dynamodb describe-table --table-name orders >/dev/null 2>&1 || break; sleep 1; done
fi
