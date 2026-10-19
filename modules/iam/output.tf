output "ecs_execution_role_arn" {
  value       = aws_iam_role.ecs_execution_role.arn
  description = "ARN of the ECS execution role"
}

output "ec2_instance_profile_name" {
  value       = aws_iam_instance_profile.ec2_instance_profile.name
  description = "Name of the EC2 instance profile for ECS cluster instances"
}

output "lambda_exec_role_arn" {
  value       = aws_iam_role.lambda_exec_role.arn
  description = "ARN of the Lambda execution role"
}