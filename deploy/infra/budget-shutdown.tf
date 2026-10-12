

data "archive_file" "budget_shutdown" {
  type        = "zip"
  source_file = "${path.module}/lambda/budget_shutdown.py"
  output_path = "${path.module}/lambda/budget_shutdown.zip"
}

resource "aws_sns_topic" "budget_shutdown" {
  name = "beanstalk-grows-budget-shutdown"
}

data "aws_iam_policy_document" "budget_shutdown_topic" {
  statement {
    sid    = "AllowAWSBudgetsToPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.budget_shutdown.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:budgets::${data.aws_caller_identity.current.account_id}:budget/beanstalk-grows-demo"
      ]
    }
  }
}

resource "aws_sns_topic_policy" "budget_shutdown" {
  arn    = aws_sns_topic.budget_shutdown.arn
  policy = data.aws_iam_policy_document.budget_shutdown_topic.json
}

resource "aws_iam_role" "budget_shutdown_lambda" {
  name = "beanstalk-grows-budget-shutdown-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "budget_shutdown_lambda" {
  name = "beanstalk-grows-budget-shutdown"
  role = aws_iam_role.budget_shutdown_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["elasticbeanstalk:TerminateEnvironment"]
        Resource = "arn:aws:elasticbeanstalk:${var.aws_region}:${data.aws_caller_identity.current.account_id}:environment/beanstalk-grows/beanstalk-grows-env"
      }
    ]
  })
}

resource "aws_lambda_function" "budget_shutdown" {
  function_name    = "beanstalk-grows-budget-shutdown"
  role             = aws_iam_role.budget_shutdown_lambda.arn
  handler          = "budget_shutdown.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.budget_shutdown.output_path
  source_code_hash = data.archive_file.budget_shutdown.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      BUDGET_NAME      = "beanstalk-grows-demo"
      ENVIRONMENT_NAME = "beanstalk-grows-env"
      BUDGET_TOPIC_ARN = aws_sns_topic.budget_shutdown.arn
      AWS_ACCOUNT_ID   = data.aws_caller_identity.current.account_id
    }
  }

  depends_on = [aws_iam_role_policy.budget_shutdown_lambda]
}

resource "aws_lambda_permission" "allow_budget_sns" {
  statement_id  = "AllowBudgetTopicInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.budget_shutdown.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.budget_shutdown.arn
}

resource "aws_sns_topic_subscription" "budget_shutdown_lambda" {
  topic_arn = aws_sns_topic.budget_shutdown.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.budget_shutdown.arn

  depends_on = [aws_lambda_permission.allow_budget_sns]
}
