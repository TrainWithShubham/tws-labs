. "$LAB_LIB"
emulator_ready
retry 10 1 sh -c '[ "$(aws dynamodb describe-table --table-name orders --query Table.TableStatus --output text 2>/dev/null)" = ACTIVE ]' || fail "There is no ACTIVE table named orders yet. Create it first (it can take a second to become active)."
aws dynamodb describe-table --table-name orders --output json | python3 -c '
import json, sys
t = json.load(sys.stdin)["Table"]
keys = {k["AttributeName"]: k["KeyType"] for k in t["KeySchema"]}
types = {a["AttributeName"]: a["AttributeType"] for a in t["AttributeDefinitions"]}
if keys.get("customer") != "HASH": print("The partition key (HASH) should be customer."); sys.exit(1)
if keys.get("orderId") != "RANGE": print("The sort key (RANGE) should be orderId."); sys.exit(1)
if len(keys) != 2: print("The key should be exactly customer and orderId."); sys.exit(1)
if types.get("customer") != "S" or types.get("orderId") != "S": print("Both key attributes are strings (type S)."); sys.exit(1)
if (t.get("BillingModeSummary") or {}).get("BillingMode", "PROVISIONED") != "PAY_PER_REQUEST": print("Use on-demand billing: --billing-mode PAY_PER_REQUEST."); sys.exit(1)
' || exit 1
