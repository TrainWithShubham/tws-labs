variable "aws_region" {
  description = "AWS region the Beanstalk Cluster Mode environment runs in"
  type        = string
  default     = "us-west-2"
}

variable "budget_notification_email" {
  description = "Email address to notify when the project's AWS Budget threshold is crossed"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the deploy role via OIDC, as \"owner/name\""
  type        = string
}

variable "github_owner_id" {
  description = "Immutable numeric ID of the GitHub owner (user or org); `github.repository_owner_id` in Actions"
  type        = string
  default     = ""
}

variable "github_repo_id" {
  description = "Immutable numeric ID of the GitHub repo; `github.repository_id` in Actions. With the owner ID it pins the deploy role to exactly this repo"
  type        = string
  default     = ""
}

variable "ecr_repository_name" {
  description = "Name of the existing ECR repository this project deploys images to"
  type        = string
  default     = "beanstalk-grows"
}

variable "budget_limit_usd" {
  description = "Monthly AWS Budget alert threshold in USD. Choose a limit that reflects your intended spend. Budget notifications do not cap spending or automatically terminate resources."
  type        = string
  default     = "150"
}
