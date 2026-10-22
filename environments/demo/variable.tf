variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "ap-south-1"
}

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket for storing artifacts"
}

variable "project" {
  type        = string
  description = "Project name used as a prefix for resource names"
  default     = "demo"
}