. "$LAB_LIB"
emulator_ready
url() { aws sqs get-queue-url --queue-name "$1" --query QueueUrl --output text 2>/dev/null; }
q=$(url orders); [ -n "$q" ] || fail "There is no queue named orders yet."
ran_re 'sqs[[:space:]]+send-message' || fail "Send the message with aws sqs send-message."
ran_re 'sqs[[:space:]]+receive-message' || fail "Receive it with aws sqs receive-message."
ran_re 'sqs[[:space:]]+delete-message([[:space:]]|$)' || fail "Delete it with aws sqs delete-message, using the receipt handle that receive-message gave you."
n=$(aws sqs get-queue-attributes --queue-url "$q" --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible --query 'Attributes.[ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible]' --output text 2>/dev/null)
set -- $n
[ "${1:-1}" = 0 ] || fail "The queue still holds a message that has not been received."
[ "${2:-1}" = 0 ] || fail "A message is still in flight: it was received but not deleted, so it will reappear."
