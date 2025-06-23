output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority" {
  description = "Certificate authority data"
  value       = module.eks.cluster_certificate_authority
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

# output "state_bucket_name" {
#   description = "S3 bucket for Terraform state"
#   value       = aws_s3_bucket.terraform_state.id
# }

# output "dynamodb_table_name" {
#   description = "DynamoDB table for state locking"
#   value       = aws_dynamodb_table.terraform_locks.id
# }