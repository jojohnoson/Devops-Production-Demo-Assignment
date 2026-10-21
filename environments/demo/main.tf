provider "aws"{
  region = var.aws_region
}

module "vpc" {
  source = "../../modules/vpc"
  availability_zones = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
}