. "$LAB_LIB"
emulator_ready
retry 10 1 sh -c '[ "$(aws dynamodb describe-table --table-name orders --query Table.TableStatus --output text 2>/dev/null)" = ACTIVE ]' || fail "There is no ACTIVE table named orders yet. Create it first (it can take a second to become active)."
get() { aws dynamodb get-item --table-name orders --key "{\"customer\":{\"S\":\"$1\"},\"orderId\":{\"S\":\"$2\"}}" --query Item.status.S --output text 2>/dev/null; }
[ "$(get alice o-1)" = SHIPPED ] || fail "alice's order o-1 is not SHIPPED yet."
[ "$(get alice o-2)" = PLACED ] || fail "Only o-1 should change: alice's order o-2 must stay PLACED."
ran_re '[[:space:]]--condition-expression[[:space:]=]' || fail "o-1 is shipped, but the task asks you to do it only if its status is still PLACED: add a --condition-expression."
