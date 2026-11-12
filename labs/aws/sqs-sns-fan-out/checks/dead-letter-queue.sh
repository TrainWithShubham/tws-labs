. "$LAB_LIB"
emulator_ready
url() { aws sqs get-queue-url --queue-name "$1" --query QueueUrl --output text 2>/dev/null; }
[ -n "$(url orders-dlq)" ] || fail "There is no queue named orders-dlq yet."
