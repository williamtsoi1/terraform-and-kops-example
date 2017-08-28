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

ZONEID=$(terraform output -module=strata_snap r53_zone_id)
TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
cat > ${TMPFILE} << EOF
    {
      "Comment":"Upserting Traefik DNS records",
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

echo Writing DNS record for *.$SNAP_DOMAIN to $TRAEFIK_ELB_ADDRESS
aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONEID \
        --change-batch file://$TMPFILE
echo DNS Update request sent

# install secret for keel.sh
kubectl create secret docker-registry myregistrykey \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=williamtsoi \
  --docker-password=wayn3k3r \
  --docker-email=william@williamtsoi.net

# install keel.sh
kubectl create clusterrolebinding kubesystem-clusteradmin --clusterrole cluster-admin --serviceaccount=kube-system:default
helm upgrade --install keel stable/keel --values kubernetes/keel-helm-values.yaml

# Wait until keel ELB created
while [ -z "$(kubectl describe service keel-keel -n kube-system | grep Ingress | awk '{print $3}')" ]
do
    echo Waiting for Keel ELB to be created
    sleep 5
done
KEEL_ELB_ADDRESS=$(kubectl describe service keel-keel -n kube-system | grep Ingress | awk '{print $3}')
KEEL_ELB_ZONEID=$(aws elb describe-load-balancers | jq -r '.LoadBalancerDescriptions[] | select(.DNSName == $KEEL_ELB_ADDRESS) | .CanonicalHostedZoneNameID' --arg KEEL_ELB_ADDRESS ${KEEL_ELB_ADDRESS})

echo KEEL ELB address is $KEEL_ELB_ADDRESS, Zone ID is $KEEL_ELB_ZONEID

ZONEID=$(terraform output -module=strata_snap r53_zone_id)
TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
cat > ${TMPFILE} << EOF
    {
      "Comment":"Upserting KEEL DNS records",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "Name":"keel.$SNAP_DOMAIN",
            "Type":"A",
            "AliasTarget": {
              "HostedZoneId": "$KEEL_ELB_ZONEID",
              "DNSName": "$KEEL_ELB_ADDRESS",
              "EvaluateTargetHealth": false
            }
          }
        }
      ]
    }
EOF

echo Writing DNS record for keel.$SNAP_DOMAIN to $KEEL_ELB_ADDRESS
aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONEID \
        --change-batch file://$TMPFILE
echo DNS Update request sent

# Create stratasnap namespace
kubectl create -f kubernetes/namespace.yaml

# install secret for stratasnap namespace
kubectl create secret docker-registry myregistrykey \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=williamtsoi \
  --docker-password=wayn3k3r \
  --docker-email=william@williamtsoi.net \
  --namespace stratasnap

# Install spinnaker (back up option should keel.sh doesn't work out)
#   helm install --name my-release stable/spinnaker