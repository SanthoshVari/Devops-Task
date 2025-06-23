terraform {
  backend "s3" {
    bucket         = "flask-eksdevops-task"
    key            = "terraform/eks-flask-app/state.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
  }
}