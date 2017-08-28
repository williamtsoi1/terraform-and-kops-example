# terraform-stratasnap

This repository is used to manage the infrastructure of stratasnap.

Remote state management is implemented via [Terragrunt](https://github.com/gruntwork-io/terragrunt)


## Description

The purpose of this repository is to simply act as a configuration store, as well as an orchestrator for other terraform modules (eg. VPC and Cassandra modules). This module should not contain any "business logic" - any infrastructure definitions should be abstracted to their own terraform module (and git repository) and referenced from here.

This repository is also used to invoke [kops](https://github.com/kubernetes/kops) in order to create a Kubernetes cluster after Terraform is executed, using output paramaters generated from Terraform to serve as inputs to kops.

## Prerequisites
- Install [Terraform](http://terraform.io)
- Install [Terragrunt](https://github.com/gruntwork-io/terragrunt)
- Install [kops](http://github.com/kubernetes/kops) - a CLI tool used to install a Kubernetes cluster on AWS
- Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) - the CLI tool to manage a Kubernetes cluster
- Install [helm](https://helm.sh/) - a package manager for Kubernetes
- Install [jq] (https://stedolan.github.io/jq/) - a CLI JSON parser
- Install [aws cli](https://aws.amazon.com/cli/) - a CLI tool to manage AWS resources
- AWS IAM credentials need to be set up on your environment. This IAM user will need access to the following:
  - Ability to manage resources as defined in the Terraform template (eg. ec2, vpc, subnet creation)
  - Access to S3 and DynamoDB in order to access the remote state file and the distributed locks


## How to use

The `environment` folder contains a hierarchy of environments to be managed by this app. Create a new folder for each environment type (first level) and region (second level) like so:

    .
    ├── README.md
    ├── environment
    │   ├── production
    │   │   └── ap-southeast-2
    │   └── test
    │       └── ap-southeast-2
    │           ├── main.tf
    │           └── terraform.tfvars
    └── strata_snap.tf

Create a main.tf and terraform.tfvars as per the example in the test/ap-southeast-2 directory, and supply the appropriate values for your environment. In order to provision the infrastructure, run the following commands:

    cd terraform-stratasnap/test/ap-southeast-2 # substitute the directory name for the environment you've created
    terragrunt get
    terragrunt plan
    terragrunt apply
    ./kops-create-cluster.sh
    ./kubes-post-install.sh

Note: Terragrunt is used to provide a distributed lock to the terraform.tfstate file in s3.

## What is installed?

Running `terraform apply` will install:
- A VPC and subnets in a region as defined in the `terraform.tfvars` file.
- An S3 bucket containing a number of public key files for SSH access into hosts
- A bastion host so one can connect to hosts on private subnets
- A cassandra seed cluster

Running `./kops-create-cluster.sh` will install:
- A Kubernetes cluster in an existing VPC as created in the `terraform apply` step

Running `./kubes-post-install.sh` will install the following onto the Kubernetes cluster:
- Kubernetes dashboard UI. In order to access the UI you must run `kubectl proxy` and then browse to `http://localhost:8001/ui`
- Tiller - The server-side component of helm, which allows the user to use helm to install apps into the cluster
- Traefik as an ingress controller. Traefik is a reverse proxy that has support for automatically provisioning SSL certificates from letsencrypt.
- keel.sh - A simple Continuous Deployment tool for Kubernetes which periodically polls a docker image repository for new versions of an image and then deploys it into the cluster based on certain conditions.

## Networking and address allocation

In order for Terraform and kops to work together nicely, special care needs to be taken in relation to network address allocations so that there are no addressing conflicts between subnets managed by Terraform vs subnets managed by kops.

For example, given a VPC with CIDR of `10.70.0.0/16` (ie. 10.70.0.0 - 10.70.255.255), kops will automatically allocate `10.70.0.0/17` to itself for its own subnets (ie. 10.70.0.0 - 10.70.127.255), and so you should configure Terraform to only use the `10.70.128.0/17` address space (ie. 10.70.128.0 - 10.70.255.255) for subnets.