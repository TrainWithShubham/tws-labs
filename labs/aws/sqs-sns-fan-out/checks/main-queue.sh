. "$LAB_LIB"
emulator_ready
url() { aws sqs get-queue-url --queue-name "$1" --query QueueUrl --output text 2>/dev/null; }
q=$(url orders); [ -n "$q" ] || fail "There is no queue named orders yet."
aws sqs get-queue-attributes --queue-url "$q" --attribute-names RedrivePolicy --output json | python3 -c '
import json, sys
p = json.load(sys.stdin).get("Attributes", {}).get("RedrivePolicy")
if not p: print("The orders queue has no redrive policy yet."); sys.exit(1)
d = json.loads(p)
if not str(d.get("deadLetterTargetArn", "")).endswith(":orders-dlq"): print("The redrive policy should point at orders-dlq."); sys.exit(1)
if int(d.get("maxReceiveCount", 0)) != 3: print("maxReceiveCount should be 3 (it is %s)." % d.get("maxReceiveCount")); sys.exit(1)
' || exit 1
