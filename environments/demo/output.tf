output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "app_subnet_ids" {
  value = module.vpc.app_subnet_ids
}

output "data_subnet_ids" {
  value = module.vpc.data_subnet_ids
}

output "ecs_iam_role_arn" {
  value = module.iam.task_execution_role_arn
}

output "instance_profile_name" {
  value = module.iam.instance_profile_name
}

output "lambda_role_arn" {
  value = module.iam.lambda_role_arn
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "api_url" {
  value = module.lambda_api.api_url
}

output "bucket_name" {
  value = module.lambda_api.bucket_name
}

output "lambda_log_group" {
  value = module.lambda_api.lambda_log_group
}

output "ecs_log_group" {
  value = module.ecs.ecs_log_group
}