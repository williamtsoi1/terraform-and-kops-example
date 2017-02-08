# variables required to be injected into module
variable "environment_name" { }
variable "vpc_cidr" { }
variable "availability_zones" { type = "list" }
variable "public_subnets" { type = "list" }
variable "private_subnets" { type = "list" }
variable "number_of_cassandra_seeds" { }
variable "cassandra_instance_type" { }
variable "cassandra_seed_ips" { type = "list" }
variable "ssh_public_key" { }

# optional variables with defaults
variable "enable_dns_hostnames" { default = "true" }
variable "enable_dns_support" { default = "true" }
variable "enable_nat_gateway" { default = "true" }
variable "map_public_ip_on_launch" { default = "false" }

module "vpc" {
  source = "github.com/terraform-community-modules/tf_aws_vpc"
  name = "${var.environment_name}-stratasnap-vpc"
  cidr = "${var.vpc_cidr}"
  private_subnets = "${var.private_subnets}"
  public_subnets = "${var.public_subnets}"
  azs = "${var.availability_zones}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"
  enable_dns_support = "${var.enable_dns_support}"
  enable_nat_gateway = "${var.enable_nat_gateway}"
  map_public_ip_on_launch = "${var.map_public_ip_on_launch}"
}

module "cassandra-seeds" {
  source = "github.com/devop5/terraform-cassandra-seeds"
  number_of_seeds = "${var.number_of_cassandra_seeds}"
  cassandra_cluster_name = "${var.environment_name} Cassandra Cluster"
  cassandra_seed_ips = "${var.cassandra_seed_ips}"
  instance_type = "${var.cassandra_instance_type}"
  private_subnet_ids = "${module.vpc.private_subnets}"
  ssh_public_key = "${var.ssh_public_key}"
  vpc_id = "${module.vpc.vpc_id}"
  vpc_cidr = "${var.vpc_cidr}"
}

module "bastion" {
  source = "github.com/devop5/terraform-bastion"
  vpc_id = "${module.vpc.vpc_id}"
  public_subnet_ids = "${module.vpc.public_subnets}"
  ssh_public_key = "${var.ssh_public_key}"
  stack_name = "${var.environment_name}"
}
