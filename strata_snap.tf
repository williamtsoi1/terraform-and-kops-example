# variables required to be injected into module
variable "environment_name" { }
variable "snap_domain_name" { }
variable "vpc_cidr" { }
variable "availability_zones" { type = "list" }
variable "public_subnets" { type = "list" }
variable "private_subnets" { type = "list" }
variable "number_of_cassandra_seeds" { }
variable "cassandra_instance_type" { }
variable "cassandra_seed_ips" { type = "list" }
variable "ssh_public_key" { }
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
  source = "github.com/devop5/terraform-cassandra-seeds"
  number_of_seeds = "${var.number_of_cassandra_seeds}"
  cassandra_cluster_name = "${var.environment_name} Cassandra Cluster"
  cassandra_seed_ips = "${var.cassandra_seed_ips}"
  instance_type = "${var.cassandra_instance_type}"
  private_subnet_ids = "${module.vpc.private_subnets}"
  ssh_public_key = "${var.ssh_public_key}"
  vpc_id = "${module.vpc.vpc_id}"
  vpc_cidr = "${var.vpc_cidr}"
  depends_id = "${module.vpc.depends_id}"
}

module "bastion" {
  source = "github.com/devop5/terraform-bastion"
  instance_type = "t2.micro"
  vpc_id = "${module.vpc.vpc_id}"
  public_subnet_ids = "${module.vpc.public_subnets}"
  ssh_public_key = "${var.ssh_public_key}"
  stack_name = "${var.environment_name}"
  s3_bucket_name = "${var.bastion_bucket_name}"
  depends_id = "${module.vpc.depends_id}"
}

resource "aws_route53_zone" "environment_subdomain" {
  name          = "${var.environment_name}.${var.snap_domain_name}"
  force_destroy = true
  count         = "${var.environment_name == "production" ? 0 : 1}"
}

resource "aws_route53_zone" "root_domain" {
  name          = "${var.snap_domain_name}"
  force_destroy = true
  count         = "${var.environment_name == "production" ? 1 : 0}"
}

resource "aws_s3_bucket" "k8s_state_store" {
  region = "${data.aws_region.current.name}"
  bucket = "${var.environment_name}-${var.snap_domain_name}-k8s-state-store"
  acl    = "private"
  force_destroy = true
}

data "aws_region" "current" {
  current = true
}

resource "null_resource" "kube_config" {
  provisioner "local-exec" {
    command = <<EOF
kops create cluster \
    --master-zones ${join(",", var.availability_zones)} \
    --zones ${join(",", var.availability_zones)} \
    --topology private \
    --dns-zone ${aws_route53_zone.environment_subdomain.id} \
    --dns private \
    --networking calico \
    --vpc ${module.vpc.vpc_id} \
    --target=terraform \
    --out=./kubernetes \
    --state s3://${var.environment_name}-${var.snap_domain_name}-k8s-state-store \
    --name kubernetes.${var.environment_name}.${var.snap_domain_name}
EOF
  }
}
