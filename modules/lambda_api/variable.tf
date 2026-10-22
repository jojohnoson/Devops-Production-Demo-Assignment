variable "project" {
  type        = string
  description = "Project name used as a prefix for resource names"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket name (globally unique); the IAM module builds its policy from the same name"
}

variable "lambda_role_arn" {
  type        = string
  description = "Lambda execution role ARN from the IAM module"
}

variable "max_upload_bytes" {
  type        = number
  description = "Maximum accepted upload size in bytes"
  default     = 4194304
}