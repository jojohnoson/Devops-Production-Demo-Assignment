provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name   = var.bucket_name
  ecs_log_group = "/ecs/${var.project}"
  lambda_name   = "${var.project}-upload"
}

module "vpc" {
  source = "../../modules/vpc"
}

module "iam" {
  source               = "../../modules/iam"
  project              = var.project
  bucket_name          = local.bucket_name
  ecs_log_group_name   = local.ecs_log_group
  lambda_function_name = local.lambda_name
}

module "alb" {
  source            = "../../modules/alb"
  project           = var.project
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

module "ecs" {
  source                  = "../../modules/ecs"
  project                 = var.project
  log_group_name          = local.ecs_log_group
  vpc_id                  = module.vpc.vpc_id
  app_subnet_ids          = module.vpc.app_subnet_ids
  alb_sg_id               = module.alb.alb_sg_id
  target_group_arns       = module.alb.target_group_arns
  instance_profile_name   = module.iam.instance_profile_name
  task_execution_role_arn = module.iam.task_execution_role_arn

  depends_on = [module.alb]
}