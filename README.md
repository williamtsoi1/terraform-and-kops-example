# terraform-stratasnap

This repository is used to manage the infrastructure of stratasnap.

Note: Remote state management hasn't been configured yet. `terraform apply` at your own peril!

## Description

The `environment` folder contains a hierarchy of environments to be managed by this app. Create a new folder for each environment type (first level) and region (second level).

## How to use

  git clone git@github.com:DevOp5/terraform-stratasnap.git
  cd terraform-stratasnap/test/ap-southeast-2
  terraform get
  terraform plan
  terraform apply
