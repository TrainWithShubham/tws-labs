. "$LAB_LIB"
emulator_ready
retry 10 1 sh -c '[ "$(aws dynamodb describe-table --table-name orders --query Table.TableStatus --output text 2>/dev/null)" = ACTIVE ]' || fail "There is no ACTIVE table named orders yet. Create it first (it can take a second to become active)."
[ -f alice-orders.txt ] || fail "No alice-orders.txt in your home folder yet."
want=$(aws dynamodb query --table-name orders --key-condition-expression 'customer = :c' --expression-attribute-values '{":c":{"S":"alice"}}' --query Count --output text 2>/dev/null)
[ "$(tr -d '[:space:]' < alice-orders.txt)" = "$want" ] || fail "alice-orders.txt should hold only the number of alice's orders."
ran_re 'dynamodb[[:space:]]+query' || fail "The number is right, but the task asks you to get it with a query on the key (not a scan)."
