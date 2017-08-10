# variables required to be injected into module
variable "environment_name" { }
variable "snap_domain_name" { }
variable "snap_full_fqdn" { }
variable "r53_zone_id" { }
variable "vpc_cidr" { }
variable "availability_zones" { type = "list" }
variable "public_subnets" { type = "list" }
variable "private_subnets" { type = "list" }
variable "number_of_cassandra_seeds" { }
variable "cassandra_instance_type" { }
variable "cassandra_seed_ips" { type = "list" }
variable "bastion_bucket_name" { }

# optional variables with defaults
variable "enable_dns_hostnames" { default = "true" }
variable "enable_dns_support" { default = "true" }
variable "enable_nat_gateway" { default = "true" }
variable "map_public_ip_on_launch" { default = "false" }

module "vpc" {
  source = "github.com/williamtsoi1/tf_aws_vpc?ref=feature%2Fdummy-dependency"
  name = "${var.environment_name}-stratasnap-vpc"
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

module "cassandra-seeds" {
  source                 = "github.com/devop5/terraform-cassandra-seeds"
  number_of_seeds        = "${var.number_of_cassandra_seeds}"
  cassandra_cluster_name = "${var.environment_name} Cassandra Cluster"
  cassandra_seed_ips     = "${var.cassandra_seed_ips}"
  instance_type          = "${var.cassandra_instance_type}"
  private_subnet_ids     = "${module.vpc.private_subnets}"
  vpc_id                 = "${module.vpc.vpc_id}"
  vpc_cidr               = "${var.vpc_cidr}"
  ssh_key_s3_bucket      = "${var.bastion_bucket_name}"
  keys_update_frequency  = "5,20,35,50 * * * *"
  depends_id             = "${module.vpc.depends_id}"
  r53_zone_id            = "${var.r53_zone_id}"
  r53_domain             = "${var.snap_full_fqdn}"
}

module "bastion" {
  source = "github.com/devop5/terraform-bastion"
  vpc_id = "${module.vpc.vpc_id}"
  public_subnet_ids = "${module.vpc.public_subnets}"
  r53_zone_id = "${var.r53_zone_id}"
  r53_domain = "${var.snap_full_fqdn}"
  stack_name = "${var.environment_name}"
  s3_bucket_name = "${var.bastion_bucket_name}"
  depends_id = "${module.vpc.depends_id}"
}

resource "aws_s3_bucket" "k8s_state_store" {
  region = "${data.aws_region.current.name}"
  bucket = "${var.snap_full_fqdn}-k8s-state-store"
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

output "snap_full_fqdn" {
  value = "${var.snap_full_fqdn}"
}

output "k8s_state_store_bucket_name" {
  value = "${aws_s3_bucket.k8s_state_store.id}"
}
