variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "edulense"
}

variable "github_token" {
  description = "GitHub personal access token for Amplify"
  type        = string
  sensitive   = true
}

variable "github_repository" {
  description = "GitHub repository URL"
  type        = string
  default     = "https://github.com/kwameD/2026_spring_edulens.git"
}

variable "github_branch" {
  description = "GitHub branch to deploy"
  type        = string
  default     = "team_e"
}

variable "moodle_username" {
  description = "Moodle service account username"
  type        = string
}

variable "moodle_password" {
  description = "Moodle service account password"
  type        = string
  sensitive   = true
}

variable "moodle_url" {
  description = "Base URL for the Moodle instance"
  type        = string
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 512
}

variable "allowed_origins" {
  description = "Allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "enable_dynamodb" {
  description = "Enable DynamoDB for game data and reflections"
  type        = bool
  default     = true
}

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "EduLense"
    Team        = "SWEN670"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
