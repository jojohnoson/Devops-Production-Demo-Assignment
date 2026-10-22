variable "project" {
  type        = string
  description = "Project name used as a prefix for resource names"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "app_subnet_ids" {
  type        = list(string)
  description = "Private app subnet IDs where the ECS EC2 nodes run"
}

variable "alb_sg_id" {
  type        = string
  description = "ALB security group ID (EC2 nodes accept traffic only from it)"
}

variable "target_group_arns" {
  type        = map(string)
  description = "Target group ARNs keyed by service (a, b)"
}

variable "instance_profile_name" {
  type        = string
  description = "Instance profile name for the ECS EC2 nodes"
}

variable "task_execution_role_arn" {
  type        = string
  description = "ECS task execution role ARN"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for ECS nodes"
  default     = "t3.small"
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch log group name for ECS containers"
}