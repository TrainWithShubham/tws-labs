# Codifies the cost guardrail created by hand earlier in this project. The limit is
# var.budget_limit_usd (default $50). The alerts only send email; nothing here stops the
# environment. Bring the existing budget under management with `terraform import` rather than
# creating a duplicate (see README.md's bootstrap section).

resource "aws_budgets_budget" "climb_demo" {
  name         = "beanstalk-grows-demo"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  # A single 80%-actual alert fires after the money is spent. During a traffic
  # spike autoscaling can add replicas (and nodes) within hours, so also alert on
  # the *forecast* crossing the limit and on actual spend reaching 100%.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }
}
