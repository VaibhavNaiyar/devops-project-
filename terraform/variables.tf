variable "project" {
  description = "Name prefix for every resource"
  type        = string
  default     = "campusdesk"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "app_instance_count" {
  description = "App servers behind the load balancer (2+ for zero-downtime rolling deploys)"
  type        = number
  default     = 2
}

variable "app_instance_type" {
  type    = string
  default = "t3.micro" # free-tier eligible
}

variable "jenkins_instance_type" {
  type    = string
  default = "c7i-flex.large" # free-tier eligible, 2 vCPU / 4 GB (Jenkins + Docker builds)
}

variable "github_repo_url" {
  description = "Repository Jenkins builds"
  type        = string
  default     = "https://github.com/VaibhavNaiyar/devops-project-.git"
}

variable "alert_email" {
  description = "Email that receives CloudWatch alarm and budget notifications (empty = no subscription)"
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  type    = number
  default = 5
}

variable "enable_budget" {
  description = "Create the AWS Budget (needs 'IAM access to Billing information' enabled on the account)"
  type        = bool
  default     = true
}
