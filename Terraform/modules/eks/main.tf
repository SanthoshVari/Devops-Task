resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.eks_version
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
  }
  
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    module.iam,
    module.vpc
  ]
  tags = {
    Name = var.cluster_name
  }
}


resource "aws_cloudwatch_log_group" "eks_control_plane_logs" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7
  tags = {
    Name = "${var.cluster_name}-control-plane-logs"
  }
}

resource "aws_security_group" "eks_cluster_sg" {
  vpc_id = var.vpc_id
  name   = "flask-eks-control-plane-sg"
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sg-eks-control-plane"
  }
}

resource "aws_security_group" "eks_nodes_sg" {
  vpc_id = var.vpc_id
  name   = "flask-eks-worker-nodes-sg"
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.eks_cluster_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sg-eks-worker-nodes"
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "flask-node-group"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.node_group_instance_type]
  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }
  tags = {
    Name = "flask-eks-node-group"
  }
}


