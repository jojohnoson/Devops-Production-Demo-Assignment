output "api_url" {
  value       = aws_apigatewayv2_api.upload.api_endpoint
  description = "Base URL of the upload API (POST /upload)"
}

output "bucket_name" {
  value       = aws_s3_bucket.uploads.id
  description = "Upload bucket name"
}

output "function_name" {
  value       = aws_lambda_function.upload.function_name
  description = "Lambda function name"
}

output "lambda_log_group" {
  value       = aws_cloudwatch_log_group.lambda.name
  description = "CloudWatch log group of the Lambda function"
}