#!/bin/sh
kops create cluster \
  --master-zones $(terraform output -module=my_app availability_zones) \
  --zones $(terraform output -module=my_app availability_zones) \
  --topology private \
  --dns-zone $(terraform output -module=my_app r53_zone_id) \
  --networking calico \
  --vpc $(terraform output -module=my_app vpc_id) \
  --state s3://$(terraform output -module=my_app k8s_state_store_bucket_name) \
  --name kubernetes.$(terraform output -module=my_app app_full_fqdn) \
  --authorization=rbac \
  --yes
