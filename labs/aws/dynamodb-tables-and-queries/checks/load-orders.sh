. "$LAB_LIB"
emulator_ready
retry 10 1 sh -c '[ "$(aws dynamodb describe-table --table-name orders --query Table.TableStatus --output text 2>/dev/null)" = ACTIVE ]' || fail "There is no ACTIVE table named orders yet. Create it first (it can take a second to become active)."
items=$(aws dynamodb scan --table-name orders --output json 2>/dev/null) || fail "Could not read the table."
printf '%s' "$items" | python3 -c '
import json, sys
got = {(i["customer"]["S"], i["orderId"]["S"]) for i in json.load(sys.stdin)["Items"]}
want = {("alice", "o-1"), ("alice", "o-2"), ("bob", "o-3")}
if got != want: print("The table should hold exactly the three orders from orders.json (it holds %d item(s))." % len(got)); sys.exit(1)
' || exit 1
ran_re 'dynamodb[[:space:]]+batch-write-item' || fail "The orders are in, but the task asks for one batch-write-item call."
