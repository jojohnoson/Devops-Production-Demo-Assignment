terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = var.aws_region }

module "networking" {
  source   = "../../modules/networking"
  vpc_cidr = var.vpc_cidr
}

module "iam" {
  source            = "../../modules/iam"
  upload_bucket_arn = module.lambda_api.s3_bucket_arn
}

module "ecs_alb" {
  source                    = "../../modules/ecs_alb"
  aws_region                = var.aws_region
  vpc_id                    = module.networking.vpc_id
  public_subnet_ids         = module.networking.public_subnet_ids
  private_app_subnet_ids    = module.networking.private_app_subnet_ids
  ecs_execution_role_arn    = module.iam.ecs_execution_role_arn
  ec2_instance_profile_name = module.iam.ec2_instance_profile_name
}

module "lambda_api" {
  source               = "../../modules/lambda_api"
  lambda_exec_role_arn = module.iam.lambda_exec_role_arn
}