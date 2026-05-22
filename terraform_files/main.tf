provider "aws" {
  region = var.region
}

module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  env_type     = var.env_name
}

module "compute" {
  source = "./modules/compute"

  env_name = var.env_name
  region   = var.region

  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids

  public_sg_id  = module.networking.public_sg_id
  private_sg_id = module.networking.private_sg_id

  #key_name     = var.key_name
  project_name = var.project_name
}

module "alb" {
  source = "./modules/alb"

  project_name = var.project_name
  env_name     = var.env_name

  vpc_id = module.networking.vpc_id

  public_subnet_ids = module.networking.public_subnet_ids

  alb_sg_id = module.networking.alb_sg_id

  private_instance_id = module.compute.private_instance_id

  certificate_arn = var.certificate_arn

  host_header = var.host_header
}
