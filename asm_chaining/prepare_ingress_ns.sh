#!/bin/bash

# Refer https://cloud.google.com/service-mesh/docs/external-lb-gateway

ASM_INGRESSGATEWAY_NAMESPACE="api-ingress"

###### Deploy Ingress Namespace ######
kubectl create namespace ${ASM_INGRESSGATEWAY_NAMESPACE}

###### Fetch the revision label on istiod ######
kubectl get deploy -n istio-system -l app=istiod -o \
  jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}'

###### Enable the namespace for injection ######
kubectl label namespace ${ASM_INGRESSGATEWAY_NAMESPACE} \
  istio-injection- istio.io/rev=asm-1146-4 --overwrite
