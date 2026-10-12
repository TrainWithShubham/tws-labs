
import json
import os

import boto3

elasticbeanstalk = boto3.client("elasticbeanstalk")


def lambda_handler(event, context):
    expected_budget = os.environ["BUDGET_NAME"]
    expected_environment = os.environ["ENVIRONMENT_NAME"]
    expected_topic_arn = os.environ["BUDGET_TOPIC_ARN"]
    expected_account_id = os.environ["AWS_ACCOUNT_ID"]

    records = event.get("Records", [])
    if not isinstance(records, list):
        raise ValueError("Invalid SNS event")

    for record in records:
        if not isinstance(record, dict):
            continue

        sns = record.get("Sns", {})
        if not isinstance(sns, dict):
            continue

        if sns.get("TopicArn") != expected_topic_arn:
            raise ValueError("Unexpected SNS topic")

        try:
            message = json.loads(sns.get("Message", ""))
        except (TypeError, json.JSONDecodeError):
            print("Ignoring non-JSON SNS message")
            continue

        if not isinstance(message, dict):
            continue

        if message.get("accountId") != expected_account_id:
            raise ValueError("Unexpected AWS account")

        if message.get("budgetName") != expected_budget:
            continue

        notification = message.get("notification", {})
        if not isinstance(notification, dict):
            continue

        if (
            notification.get("notificationState") != "ALARM"
            or notification.get("notificationType") != "ACTUAL"
            or notification.get("thresholdType") != "PERCENTAGE"
            or notification.get("comparisonOperator") != "GREATER_THAN"
        ):
            continue

        try:
            threshold = float(notification.get("threshold", 0))
        except (TypeError, ValueError):
            print("Ignoring invalid threshold")
            continue

        if threshold < 100:
            continue

        response = elasticbeanstalk.terminate_environment(
            EnvironmentName=expected_environment
        )

        print(json.dumps({
            "action": "termination_requested",
            "environment": expected_environment,
            "status": response.get("Status"),
        }))

    return {"statusCode": 200, "body": "Processed"}
