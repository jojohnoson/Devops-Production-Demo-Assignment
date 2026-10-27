output "cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "ECS cluster name"
}

output "ecs_log_group" {
  value       = aws_cloudwatch_log_group.ecs.name
  description = "CloudWatch log group for ECS containers"
}
