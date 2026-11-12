. "$LAB_LIB"
emulator_ready
retry 10 1 sh -c '[ "$(aws dynamodb describe-table --table-name orders --query Table.TableStatus --output text 2>/dev/null)" = ACTIVE ]' || fail "There is no ACTIVE table named orders yet. Create it first (it can take a second to become active)."
ttl=$(aws dynamodb describe-time-to-live --table-name orders --output json 2>/dev/null) || fail "Could not read the table's Time to Live setting."
printf '%s' "$ttl" | python3 -c '
import json, sys
d = json.load(sys.stdin)["TimeToLiveDescription"]
if d.get("TimeToLiveStatus") not in ("ENABLED", "ENABLING"): print("Time to Live is not switched on for the table yet."); sys.exit(1)
if d.get("AttributeName") != "expiresAt": print("The TTL attribute should be expiresAt (it is %s)." % d.get("AttributeName")); sys.exit(1)
' || exit 1
