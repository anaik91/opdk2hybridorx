# Apigee Hybrid with ASM chaining


## Objective
To chain ASM ingress to externalize cert management from Apigee Hybrid.

## Disclaimer
This is not an Officially Supported Google Product!

This was only tested on GKE ! Needs tweaking for other platforms

## Pre-Requisites

* Install ASM if not already installed
```
    bash deploy_asm.sh
```

* Create Namespace for new ASM Ingress and Enable the namespace for injection
```
    bash prepare_ingress_ns.sh
```

## Deploy ASM Ingress
Run the snippet
```
RELEASE_NAME="external-asm"
helm install $RELEASE_NAME external_asm/ --debug
```

## Testing

### Using Helm test 

Run the below command 
```
RELEASE_NAME="external-asm"
helm test $RELEASE_NAME --logs
```

### Using Curl locally (provided Ingress IP is reachable) 

Use curl to test

```
ASM_INGRESS_NAMESPACE="api-ingress"
APIGEE_ENV_GROUP_HOST="external.asm.com"
INGRESS_IP=$(kubectl get svc \
	-n api-ingress -o \
	jsonpath='{$.items[0].status.loadBalancer.ingress[0].ip}')
PROXY_ENDPOINT="mock"
curl https://$APIGEE_ENV_GROUP_HOST/$PROXY_ENDPOINT \
	--connect-to $APIGEE_ENV_GROUP_HOST:443:$INGRESS_IP  -k -v
```

## Copyright

Copyright 2023 Google LLC. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreement with Google.
