# output "github_actions_role_arn" {
#   value = aws_iam_role.github_actions_role.arn
# }

# Variables
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "flask-eks-cluster"
}

variable "github_oidc_provider_arn" {
  description = "ARN of the OIDC provider for GitHub Actions"
  type        = string
}

variable "s3_reports_bucket" {
  description = "S3 bucket for reports"
  type        = string
  default     = "Terraform/backend.tf"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Terraform locks"
  type        = string
  default     = "terraform-locks"
}


