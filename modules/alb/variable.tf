variable "project" {
  type        = string
  description = "Project name used as a prefix for resource names"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the ALB (needs 2 AZs)"
}