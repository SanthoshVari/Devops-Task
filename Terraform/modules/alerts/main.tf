
resource "aws_sns_topic" "flask_app_alerts" {
  name = "flask-app-alerts"
}


resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.flask_app_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "eks-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Triggers when EKS node CPU usage exceeds 80% for 10 minutes"
  alarm_actions       = [aws_sns_topic.flask_app_alerts.arn]
  dimensions = {
    ClusterName = var.eks_cluster_name
  }
}


resource "aws_cloudwatch_metric_alarm" "node_disk_pressure" {
  alarm_name          = "eks-node-disk-pressure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "node_filesystem_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Triggers when EKS node filesystem usage exceeds 85%"
  alarm_actions       = [aws_sns_topic.flask_app_alerts.arn]
  dimensions = {
    ClusterName = var.eks_cluster_name
  }
}


resource "aws_cloudwatch_metric_alarm" "pod_crashes" {
  alarm_name          = "flask-app-pod-crashes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "pod_number_of_restarts"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggers when Flask app pod restarts occur"
  alarm_actions       = [aws_sns_topic.flask_app_alerts.arn]
  dimensions = {
    ClusterName = var.eks_cluster_name
    Namespace   = "default"
    PodName     = "flask-app"
  }
}

