#!/bin/bash

# Refer https://cloud.google.com/service-mesh/docs/external-lb-gateway

PROJECT_ID="apigee-hybrid-378710"
LOCATION="us-central1"
CLUSTER_NAME="apigee-hybrid-cluster"
ASM_INGRESSGATEWAY_NAMESPACE="api-ingress"
#### Deploy ASM ####
curl https://storage.googleapis.com/csm-artifacts/asm/asmcli > asmcli
chmod +x asmcli
./asmcli install \
      -p $PROJECT_ID \
      -l $LOCATION \
      -n $CLUSTER_NAME \
      --fleet_id $PROJECT_ID \
      --verbose \
      --output_dir $CLUSTER_NAME \
        --enable_all \
        --ca mesh_ca \
        --option legacy-default-ingressgateway
#### Deploy ASM ####

###### Deploy Ingress Namespace ######
kubectl create namespace ${ASM_INGRESSGATEWAY_NAMESPACE}

###### Fetch the revision label on istiod ######
kubectl get deploy -n istio-system -l app=istiod -o \
  jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}'

###### Enable the namespace for injection ######
kubectl label namespace ${ASM_INGRESSGATEWAY_NAMESPACE} \
  istio-injection- istio.io/rev=asm-1146-4 --overwrite
