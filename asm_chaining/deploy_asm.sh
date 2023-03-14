#!/bin/bash


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