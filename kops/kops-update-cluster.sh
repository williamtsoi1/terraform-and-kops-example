#!/bin/sh
kops update cluster \
  --state s3://$(terraform output -module=strata_snap k8s_state_store_bucket_name) \
  --name kubernetes.$(terraform output -module=strata_snap snap_full_fqdn) \
  --yes

export KOPS_FEATURE_FLAGS="+DrainAndValidateRollingUpdate"
kops rolling-update cluster \
  --state s3://$(terraform output -module=strata_snap k8s_state_store_bucket_name) \
  --name kubernetes.$(terraform output -module=strata_snap snap_full_fqdn)\
  --yes \
  --fail-on-validate-error="false" \
  --master-interval=8m \
  --node-interval=8m