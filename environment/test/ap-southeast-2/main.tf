variable "environment_name" { }
variable "snap_domain_name" { }
variable "snap_full_fqdn" { }
variable "r53_zone_id" { }
variable "region" { }
variable "vpc_cidr" { }
variable "availability_zones" { type = "list" }
variable "public_subnets" { type = "list" }
variable "private_subnets" { type = "list" }
variable "number_of_cassandra_seeds" { }
variable "cassandra_instance_type" { }
variable "cassandra_seed_ips" { type = "list" }
variable "ssh_public_key" { }
variable "bastion_bucket_name" { }

provider aws {
  region  = "${var.region}"
  profile = "${var.environment_name}"
}

module "strata_snap" {
  source = "../../../"
  environment_name = "${var.environment_name}"
  snap_domain_name = "${var.snap_domain_name}"
  snap_full_fqdn = "${var.snap_full_fqdn}"
  r53_zone_id = "${var.r53_zone_id}"
  vpc_cidr = "${var.vpc_cidr}"
  availability_zones = "${var.availability_zones}"
  public_subnets = "${var.public_subnets}"
  private_subnets = "${var.private_subnets}"
  number_of_cassandra_seeds = "${var.number_of_cassandra_seeds}"
  cassandra_instance_type = "${var.cassandra_instance_type}"
  cassandra_seed_ips = "${var.cassandra_seed_ips}"
  ssh_public_key = "${var.ssh_public_key}"
  bastion_bucket_name = "${var.bastion_bucket_name}"
}

terraform {
  backend "s3" {}
}