variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_1" {
  type        = string
  description = "List of CIDR blocks for public subnets"
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr_2" {
  type        = string
  description = "List of CIDR blocks for public subnets"
  default     = "10.0.2.0/24"
}

variable "availability_zone-1" {
  type        = string
  description = "List of availability zones for the subnets"
  default     = "ap-south-1a"
}

variable "availability_zone-2" {
  type        = string
  description = "List of availability zones for the subnets"
  default     = "ap-south-1b"
}

variable "private_subnet_cidr_1" {
  type        = string
  description = "List of CIDR blocks for private subnets"
  default     = "10.0.3.0/24"
}

variable "private_subnet_cidr_2" {
  type        = string
  description = "List of CIDR blocks for private subnets"
  default     = "10.0.4.0/24"
}

variable "private_subnet_cidr_3" {
  type        = string
  description = "List of CIDR blocks for private subnets"
  default     = "10.0.5.0/24"
}

variable "private_subnet_cidr_4" {
  type        = string
  description = "List of CIDR blocks for private subnets"
  default     = "10.0.6.0/24"
}

