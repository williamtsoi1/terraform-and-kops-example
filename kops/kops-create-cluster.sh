#!/bin/sh
kops create cluster \
  --master-zones $(terraform output -module=strata_snap availability_zones) \
  --zones $(terraform output -module=strata_snap availability_zones) \
  --topology private \
  --dns-zone $(terraform output -module=strata_snap r53_zone_id) \
  --networking calico \
  --vpc $(terraform output -module=strata_snap vpc_id) \
  --state s3://$(terraform output -module=strata_snap k8s_state_store_bucket_name) \
  --name kubernetes.$(terraform output -module=strata_snap snap_full_fqdn) \
  --authorization=rbac \
  --yes
