terraform {
  backend "s3" {
    bucket         = "${var.state_bucket_name}-${random_string.bucket_suffix.result}"
    key            = "terraform/eks-flask-app/state.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
  }
}