#!/bin/sh
kops delete cluster \
  --state s3://$(terraform output -module=my_app k8s_state_store_bucket_name) \
  --name kubernetes.$(terraform output -module=my_app app_full_fqdn) \
  --yes
