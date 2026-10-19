output "s3_bucket_arn" {
  value       = aws_s3_bucket.upload_bucket.arn
  description = "ARN of the file upload S3 bucket"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.upload_bucket.id
  description = "Name/ID of the file upload S3 bucket"
}

output "api_endpoint" {
  value       = aws_apigatewayv2_api.http_api.api_endpoint
  description = "Public HTTP endpoint URL for API Gateway"
}