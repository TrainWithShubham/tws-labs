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
  description = "Monthly AWS Budget limit in USD. The default is $50, a tripwire rather than a forecast: one always-on Cluster Mode environment measured about $9.9/day (~$300/month; the EKS control plane alone is ~$0.10/hr, ~$73/month), so it crosses $50 in about a week. The alert only emails, it does not stop anything. Set this to what you actually intend to spend, especially for a public event."
  type        = string
  default     = "50"
}
