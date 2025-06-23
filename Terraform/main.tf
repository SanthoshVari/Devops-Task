resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.state_bucket_name}-${random_string.bucket_suffix.result}"
  tags = {
    Name = "flask-eks-terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    Name = "terraform-locks"
  }
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = var.vpc_cidr
  region   = var.region
}

module "iam" {
  source = "./modules/iam"
}

module "eks" {
  source = "./modules/eks"

  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  cluster_name        = var.cluster_name
  eks_version         = var.eks_version
  node_group_instance_type = var.node_group_instance_type
  node_group_min_size = var.node_group_min_size
  node_group_max_size = var.node_group_max_size
  node_group_desired_size = var.node_group_desired_size
  my_ip               = var.my_ip
  cluster_role_arn    = module.iam.eks_cluster_role_arn
  node_group_role_arn = module.iam.eks_node_group_role_arn
  depends_on          = [module.iam]
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  cluster_name = module.eks.cluster_name
  depends_on   = [module.eks]
}