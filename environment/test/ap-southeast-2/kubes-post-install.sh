# This script performs a few tasks to install various components to a newly 
# provisioned Kubernetes cluster:
#
# 1. Install Kubernetes dashboard UI. In order to access the UI you must run:
#        kubectl proxy
#    and then browse to http://localhost:8001/ui
#
# 2. Install helm & tiller (https://github.com/kubernetes/helm), and also 
#    verifies your local PC installation to ensure the correct version is 
#    installed.
#
# 3. Install traefik (https://traefik.io) as an ingress controller. Traefik is
#    a reverse proxy that has support for automatically provisioning SSL 
#    certificates from letsencrypt.
#
# Prerequisites:
#
# Please ensure the following is installed on your PC before running this script
#   - kubectl (and ensure the context is set to the correct cluster)
#   - helm
#   - jq
#   - aws cli

#!/bin/sh
SNAP_DOMAIN=$(terraform output -module=strata_snap snap_full_fqdn)

# install dashboard UI
kubectl create -f https://git.io/kube-dashboard

# install helm to server
helm init
helm repo update
# Need to wait until tiller is installed
sleep 30

# install traefik (ingress controller)
helm install --name ingress-controller --namespace kube-system \
  --values traefik-helm-values.yaml stable/traefik

# Wait until traefik & deis workflow ELBs created
while [ -z "$(kubectl describe service ingress-controller-traefik -n kube-system | grep Ingress | awk '{print $3}')" ]
do
    echo Waiting for Traefik ELBs to be created
    sleep 5
done

TRAEFIK_ELB_ADDRESS=$(kubectl describe service ingress-controller-traefik -n kube-system | grep Ingress | awk '{print $3}') 
TRAEFIK_ELB_ZONEID=$(aws elb describe-load-balancers | jq -r '.LoadBalancerDescriptions[] | select(.DNSName == $TRAEFIK_ELB_ADDRESS) | .CanonicalHostedZoneNameID' --arg TRAEFIK_ELB_ADDRESS ${TRAEFIK_ELB_ADDRESS})

echo Traefik ELB address is $TRAEFIK_ELB_ADDRESS, Zone ID is $TRAEFIK_ELB_ZONEID

ZONEID=$(terraform output -module=strata_snap r53_zone_id)
TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
cat > ${TMPFILE} << EOF
    {
      "Comment":"Upserting Deis Workflow and Traefik DNS records",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "Name":"*.$SNAP_DOMAIN",
            "Type":"A",
            "AliasTarget": {
              "HostedZoneId": "$TRAEFIK_ELB_ZONEID",
              "DNSName": "$TRAEFIK_ELB_ADDRESS",
              "EvaluateTargetHealth": false
            }
          }
        }
      ]
    }
EOF

aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONEID \
        --change-batch file://"$TMPFILE"


# Install spinnaker
#   helm install --name my-release stable/spinnaker