variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "flask-eks-cluster"
}

variable "alert_email" {
  description = "Email address for SNS notifications"
  type        = string
}