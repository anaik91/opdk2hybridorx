# Apigee Hybrid selective org decommission


## Objective
To Decommission a specific Apigee Org in a Multi-Org Apigee Hybrid Cluster.

## Disclaimer
This is not an Officially Supported Google Product!

## Pre-Requisites
* Install Pre-Reqs like `apigeeclt` , `kpt` , `jq` etc using below script
```
    sudo bash prepare.sh
```

* export the KUBECONFIG to point to K8s cluster.
```
    export KUBECONFIG="<path to kubeconfig file>"
```

* Please fill in `input.json`
```
{
	"apigeectl_installation": "<directory under $HOME to place pre-req binaries>",
	"apigee_org_name": "<Apigee Org Name>",
	"project_id":"<GCP Project ID containting Apigee Org instance>",
	"apigeectl_version": "<Apigee Hybrid Version>",
	"script_path" : "<Path containing current script>",
	"cassandra_client_image" : "<Cassandra Client Image>"
}
```
        
    
## Highlevel Working 
* Delete Apigee Org Virtual Hosts
* Delete Apigee Org Environments 
* Delete Apigee Orgs
* Drop Cassandra Keyspaces for the Org
* Delete Keyspaces directory from Cassandra Pods


## Running
Run the Script as below
```
bash decommission.sh
```

## Copyright

Copyright 2023 Google LLC. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreement with Google.
