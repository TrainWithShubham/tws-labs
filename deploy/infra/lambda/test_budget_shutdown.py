import json
import os
import sys
import types
import unittest
from unittest.mock import Mock, patch

# Replace boto3 with a mock before importing the handler.
mock_boto3 = types.ModuleType("boto3")
mock_beanstalk = Mock()
mock_boto3.client = Mock(return_value=mock_beanstalk)
sys.modules["boto3"] = mock_boto3

import budget_shutdown


class BudgetShutdownTests(unittest.TestCase):
    def setUp(self):
        self.env = patch.dict(os.environ, {
            "BUDGET_NAME": "beanstalk-grows-demo",
            "ENVIRONMENT_NAME": "beanstalk-grows-env",
            "BUDGET_TOPIC_ARN": "arn:aws:sns:us-west-2:123456789012:budget-topic",
            "AWS_ACCOUNT_ID": "123456789012",
        })
        self.env.start()
        self.addCleanup(self.env.stop)
        mock_beanstalk.reset_mock()
        mock_beanstalk.terminate_environment.return_value = {
            "Status": "Terminating"
        }

    def make_event(self, threshold, state="ALARM", **overrides):
        notification = {
            "notificationState": state,
            "notificationType": "ACTUAL",
            "thresholdType": "PERCENTAGE",
            "comparisonOperator": "GREATER_THAN",
            "threshold": threshold,
        }
        notification.update(overrides)

        message = {
            "accountId": "123456789012",
            "budgetName": "beanstalk-grows-demo",
            "notification": notification,
        }
        return {
            "Records": [{
                "Sns": {
                    "TopicArn": os.environ["BUDGET_TOPIC_ARN"],
                    "Message": json.dumps(message),
                }
            }]
        }

    def test_100_percent_actual_alarm_requests_termination(self):
        budget_shutdown.lambda_handler(self.make_event(100), None)
        mock_beanstalk.terminate_environment.assert_called_once_with(
            EnvironmentName="beanstalk-grows-env"
        )

    def test_80_percent_alert_does_not_terminate(self):
        budget_shutdown.lambda_handler(self.make_event(80), None)
        mock_beanstalk.terminate_environment.assert_not_called()

    def test_ok_notification_does_not_terminate(self):
        budget_shutdown.lambda_handler(self.make_event(100, state="OK"), None)
        mock_beanstalk.terminate_environment.assert_not_called()

    def test_forecast_notification_does_not_terminate(self):
        budget_shutdown.lambda_handler(
            self.make_event(100, notificationType="FORECASTED"), None
        )
        mock_beanstalk.terminate_environment.assert_not_called()

    def test_invalid_threshold_does_not_terminate(self):
        budget_shutdown.lambda_handler(self.make_event("invalid"), None)
        mock_beanstalk.terminate_environment.assert_not_called()


if __name__ == "__main__":
    unittest.main()
