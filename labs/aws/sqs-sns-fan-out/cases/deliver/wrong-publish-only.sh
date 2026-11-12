TOPIC=$(aws sns list-topics --query "Topics[?ends_with(TopicArn, ':order-events')].TopicArn | [0]" --output text)
aws sns publish --topic-arn "$TOPIC" --message order-created
