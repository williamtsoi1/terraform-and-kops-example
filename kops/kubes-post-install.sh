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
APP_DOMAIN=$(terraform output -module=my_app app_full_fqdn)

# Gives the admin user cluster admin access (on all namespaces)
kubectl create clusterrolebinding root-cluster-admin-binding --clusterrole=cluster-admin --user=admin

# install dashboard UI
kubectl create -f https://git.io/kube-dashboard

# Create Tiller (helm's server-side component) service account, and install Tiller to server.
kubectl -n kube-system create sa tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller --upgrade
helm repo update

# Need to wait until tiller is installed
while [ -z "$(kubectl get pods --namespace kube-system | grep tiller | grep Running)" ]
do
    echo Waiting for Tiller pod to be running
    sleep 5
done
echo Tiller pod created

# install traefik as an ingress controller
helm install --name ingress-controller --namespace kube-system \
  --values kubernetes/traefik-helm-values.yaml stable/traefik

# Wait until traefik ELB created
while [ -z "$(kubectl describe service ingress-controller-traefik -n kube-system | grep Ingress | awk '{print $3}')" ]
do
    echo Waiting for Traefik ELB to be created
    sleep 5
done

TRAEFIK_ELB_ADDRESS=$(kubectl describe service ingress-controller-traefik -n kube-system | grep Ingress | awk '{print $3}') 
TRAEFIK_ELB_ZONEID=$(aws elb describe-load-balancers | jq -r '.LoadBalancerDescriptions[] | select(.DNSName == $TRAEFIK_ELB_ADDRESS) | .CanonicalHostedZoneNameID' --arg TRAEFIK_ELB_ADDRESS ${TRAEFIK_ELB_ADDRESS})

echo Traefik ELB address is $TRAEFIK_ELB_ADDRESS, Zone ID is $TRAEFIK_ELB_ZONEID

ZONEID=$(terraform output -module=my_app r53_zone_id)
TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
cat > ${TMPFILE} << EOF
    {
      "Comment":"Upserting Traefik DNS records",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "Name":"*.$APP_DOMAIN",
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

echo Writing DNS record for *.$APP_DOMAIN to $TRAEFIK_ELB_ADDRESS
aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONEID \
        --change-batch file://$TMPFILE
echo DNS Update request sent

# Create app namespace
kubectl create -f kubernetes/namespace.yaml