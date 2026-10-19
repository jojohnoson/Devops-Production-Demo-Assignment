output "alb_dns_url" {
  value       = "http://${module.ecs_alb.alb_dns_name}"
  description = "Open this URL in your browser or curl to test NGINX load balancing"
}

output "api_upload_endpoint" {
  value       = "${module.lambda_api.api_endpoint}/upload"
  description = "POST files to this endpoint URL"
}

output "s3_bucket_name" {
  value       = module.lambda_api.s3_bucket_name
  description = "S3 bucket where uploaded files are stored"
}