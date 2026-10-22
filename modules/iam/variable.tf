variable "project" {
  type        = string
  description = "Project name for resource naming"
}

variable "bucket_name" {
  type        = string
  description = "Name of the S3 uploads bucket"
}

variable "ecs_log_group_name" {
  type        = string
  description = "Name of the CloudWatch log group for ECS tasks"
}

variable "lambda_function_name" {
  type        = string
  description = "Name of the Lambda function"
}