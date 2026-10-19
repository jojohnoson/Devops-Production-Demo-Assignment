variable "aws_region" {
  type        = string
  description = "AWS Region for CloudWatch log groups"
  default     = "us-east-1"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where resources will be created"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs for the ALB"
}

variable "private_app_subnet_ids" {
  type        = list(string)
  description = "List of private app subnet IDs for the ECS ASG"
}

variable "ecs_execution_role_arn" {
  type        = string
  description = "IAM execution role ARN for ECS tasks"
}

variable "ec2_instance_profile_name" {
  type        = string
  description = "IAM instance profile name for EC2 instances"
}