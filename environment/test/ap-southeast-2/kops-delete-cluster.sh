#!/bin/sh
kops delete cluster \
  --state s3://$(terraform output -module=strata_snap k8s_state_store_bucket_name) \
  --name kubernetes.$(terraform output -module=strata_snap snap_full_fqdn) \
  --yes
