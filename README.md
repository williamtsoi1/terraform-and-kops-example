# terraform-stratasnap

This repository is used to manage the infrastructure of stratasnap. 

Note: Remote state management hasn't been configured yet. `terraform apply` at your own peril!

## Description

The purpose of this repository is to simply act as a configuration store, as well as an orchestrator for other terraform modules (eg. VPC and Cassandra modules). This module should not contain any "business logic" - any infrastructure definitions should be abstracted to their own terraform module (and git repository) and referenced from here. 

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
    terraform get
    terraform plan
    terraform apply
