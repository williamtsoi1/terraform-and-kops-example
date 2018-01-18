# variables required to be injected into module
variable "environment_name" { }
variable "app_domain_name" { }
variable "app_full_fqdn" { }
variable "r53_zone_id" { }
variable "vpc_cidr" { }
variable "availability_zones" { type = "list" }
variable "public_subnets" { type = "list" }
variable "private_subnets" { type = "list" }

# optional variables with defaults
variable "enable_dns_hostnames" { default = "true" }
variable "enable_dns_support" { default = "true" }
variable "enable_nat_gateway" { default = "true" }
variable "map_public_ip_on_launch" { default = "false" }

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "${var.environment_name}-myapp-vpc"
  cidr = "${var.vpc_cidr}"
  private_subnets = "${var.private_subnets}"
  public_subnets = "${var.public_subnets}"
  azs = "${var.availability_zones}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"
  enable_dns_support = "${var.enable_dns_support}"
  enable_nat_gateway = "${var.enable_nat_gateway}"
  enable_s3_endpoint = true
  map_public_ip_on_launch = "${var.map_public_ip_on_launch}"
}

resource "aws_s3_bucket" "k8s_state_store" {
  region = "${data.aws_region.current.name}"
  bucket = "${var.app_full_fqdn}-k8s-state-store"
  acl    = "private"
  force_destroy = true
}

data "aws_region" "current" {
  current = true
}

output "vpc_id" {
  value = "${module.vpc.vpc_id}"
}

output "availability_zones" {
  value = "${join(",", var.availability_zones)}"
}

output "r53_zone_id" {
  value = "${var.r53_zone_id}"
}

output "app_full_fqdn" {
  value = "${var.app_full_fqdn}"
}

output "k8s_state_store_bucket_name" {
  value = "${aws_s3_bucket.k8s_state_store.id}"
}
