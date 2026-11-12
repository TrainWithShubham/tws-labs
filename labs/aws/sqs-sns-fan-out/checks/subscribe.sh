. "$LAB_LIB"
emulator_ready
url() { aws sqs get-queue-url --queue-name "$1" --query QueueUrl --output text 2>/dev/null; }
q=$(url orders); [ -n "$q" ] || fail "There is no queue named orders yet."
qarn=$(aws sqs get-queue-attributes --queue-url "$q" --attribute-names QueueArn --query Attributes.QueueArn --output text)
topic=$(aws sns list-topics --query "Topics[?ends_with(TopicArn, ':order-events')].TopicArn | [0]" --output text 2>/dev/null)
{ [ -n "$topic" ] && [ "$topic" != None ]; } || fail "There is no SNS topic named order-events yet."
found=$(aws sns list-subscriptions-by-topic --topic-arn "$topic" --query "Subscriptions[?Protocol=='sqs' && Endpoint=='$qarn'].SubscriptionArn | [0]" --output text 2>/dev/null)
{ [ -n "$found" ] && [ "$found" != None ]; } || fail "The orders queue is not subscribed to order-events with the sqs protocol yet."
