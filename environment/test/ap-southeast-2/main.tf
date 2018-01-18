variable "environment_name" { }
variable "app_domain_name" { }
variable "app_full_fqdn" { }
variable "r53_zone_id" { }
variable "region" { }
variable "vpc_cidr" { }
variable "availability_zones" { type = "list" }
variable "public_subnets" { type = "list" }
variable "private_subnets" { type = "list" }

provider aws {
  region  = "${var.region}"
  profile = "${var.environment_name}"
}

module "my_app" {
  source = "../../../"
  environment_name = "${var.environment_name}"
  app_domain_name = "${var.app_domain_name}"
  app_full_fqdn = "${var.app_full_fqdn}"
  r53_zone_id = "${var.r53_zone_id}"
  vpc_cidr = "${var.vpc_cidr}"
  availability_zones = "${var.availability_zones}"
  public_subnets = "${var.public_subnets}"
  private_subnets = "${var.private_subnets}"
}

terraform {
  backend "s3" {}
}