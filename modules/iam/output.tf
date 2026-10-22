
output "instance_profile_name" {
  value       = aws_iam_instance_profile.instance.name
  description = "Instance profile for the ECS EC2 nodes"
}

output "lambda_role_arn" {
  value       = aws_iam_role.lambda.arn
  description = "Lambda execution role ARN"
}

output "task_execution_role_arn" {
  value       = aws_iam_role.ecs_iam.arn
  description = "ECS task execution role ARN"
}