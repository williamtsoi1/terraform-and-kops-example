# This script performs a few tasks to install various components to a newly 
# provisioned Kubernetes cluster:
#
# 1. Install Kubernetes dashboard UI. In order to access the UI you must run:
#        kubectl proxy
#    and then browse to http://localhost:8001/ui
#
# 2. Install helm (https://github.com/kubernetes/helm), and also verify your 
#    local PC installation to ensure the correct version is installed
#
# 3. Install traefik (https://traefik.io) as an ingress controller. Traefik is
#    a reverse proxy that has support for automatically provisioning SSL 
#    certificates from letsencrypt.
#
# 4. Install Deis Workflow (https://deis.com/workflow/), a CI/CD solution for
#    Kubernetes
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

# install deis workflow
helm repo add deis https://charts.deis.com/workflow
helm install deis/workflow \
  --name my-workflow \
  --namespace deis \
  --set global.experimental_native_ingress=true,controller.platform_domain=$SNAP_DOMAIN

# Wait until traefik & deis workflow ELBs created
while [ -z "$(kubectl describe service ingress-controller-traefik -n kube-system | grep Ingress | awk '{print $3}')" || -z "$(kubectl describe service deis-builder -n deis | grep Ingress | awk '{print $3}')" ]
do
    echo Waiting for Traefik and Deis Workflow ELBs to be created
    sleep 5
done

TRAEFIK_ELB_ADDRESS=$(kubectl describe service ingress-controller-traefik -n kube-system | grep Ingress | awk '{print $3}') 
TRAEFIK_ELB_ZONEID=$(aws elb describe-load-balancers | jq -r '.LoadBalancerDescriptions[] | select(.DNSName == $TRAEFIK_ELB_ADDRESS) | .CanonicalHostedZoneNameID' --arg TRAEFIK_ELB_ADDRESS ${TRAEFIK_ELB_ADDRESS})
DEIS_BUILDER_ELB_ADDRESS=$(kubectl describe service deis-builder -n deis | grep Ingress | awk '{print $3}')
DEIS_BUILDER_ELB_ZONEID=$(aws elb describe-load-balancers | jq -r '.LoadBalancerDescriptions[] | select(.DNSName == $DEIS_BUILDER_ELB_ADDRESS) | .CanonicalHostedZoneNameID' --arg DEIS_BUILDER_ELB_ADDRESS ${DEIS_BUILDER_ELB_ADDRESS})

echo Traefik ELB address is $TRAEFIK_ELB_ADDRESS, Zone ID is $TRAEFIK_ELB_ZONEID
echo Deis Builder ELB address is $DEIS_BUILDER_ELB_ADDRESS, Zone ID is $DEIS_BUILDER_ELB_ZONEID

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
        },
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "Name":"deis-builder.$SNAP_DOMAIN",
            "Type":"A",
            "AliasTarget": {
              "HostedZoneId": "$DEIS_BUILDER_ELB_ZONEID",
              "DNSName": "$DEIS_BUILDER_ELB_ADDRESS",
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


# Need to wait until workflow pods are created & ready. Use the following to watch status of pods.
# This takes a few minutes
#   kubectl --namespace=deis get pods

# deis router creates an ELB automatically... need to look at externalising 
# this with an existing ELB generated through terraform

# Scale deis router for HA
#    kubectl --namespace=deis scale --replicas=2 deployment/deis-router

# Create alias wildcard record of *.workflow.test1.stratasnap.com.au to point to the ELB
#   deis register http://deis.test1.stratasnap.com.au

# Log in to Deis Workflow using your user
#   deis login http://deis.test1.stratasnap.com.au

# add you ssh keys
#   deis keys:add <ssh keys>

# Application install
#   cd <local repo directory> 
#   deis create

# Application deploy
#   git push deis master

# Application deploy from docker hub
#   deis registry:set username=<username> password=<secret> -a <application_name>
#   deis pull <image>:<tag>

# To uninstall deis workflow. Find the release name by 
#   helm list
# Then run
#   helm delete <release_name>
#   kubectl delete ns deis

