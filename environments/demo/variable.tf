variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "ap-south-1"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones for the subnets"
}