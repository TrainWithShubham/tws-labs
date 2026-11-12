. "$LAB_LIB"
emulator_ready
url() { aws sqs get-queue-url --queue-name "$1" --query QueueUrl --output text 2>/dev/null; }
q=$(url orders); [ -n "$q" ] || fail "There is no queue named orders yet."
ran_re 'sns[[:space:]]+publish' || fail "Publish the message with aws sns publish."
count() { aws sqs get-queue-attributes --queue-url "$q" --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible --query 'sum(Attributes.*.to_number(@))' --output text 2>/dev/null; }
arrived() { [ "$(count)" -ge 1 ] 2>/dev/null; }
retry 5 1 arrived && exit 0
pol=$(aws sqs get-queue-attributes --queue-url "$q" --attribute-names Policy --query Attributes.Policy --output text 2>/dev/null)
if [ -z "$pol" ] || [ "$pol" = None ]; then fail "Nothing arrived, and the orders queue has no policy. A queue only accepts messages from senders its policy allows: let the topic send to it, then publish again."; fi
fail "Nothing has arrived in the queue yet. Check that the policy allows sns.amazonaws.com to send to this queue from your topic, then publish again."
