# Apigee OPDK to Apigee X/Hybrid API proxy migration Validator


## Objective
To validate Apigee API Proxy Bundles exported from Apigee OPDK against Apigee X/Hybrid.

## Disclaimer
This is not an Officially Supported Google Product!

## Pre-Requisites
* python3.x
* Please Install required Python Libs 
```
    python3 -m pip install requirements.txt
```
* Please fill in `input.properties`
```
    [common]
    export_dir=proxies               # Directory to export APIS to OR Read the APIs from 
    skip_export=false                # Set this to true to read the Proxy bundles from export_dir  | false to Download from OPDK

    [opdk]
    protocol=http                    # Apigee OPDK Managemnt API Protocol
    management_server=34.131.144.184 # Apigee OPDK Managemnt API Server
    management_port=8080             # Apigee OPDK Managemnt API Port
    user=opdk@google.com             # Apigee OPDK Managemnt API User
    password=Test@1234               # Apigee OPDK Managemnt API Password
    org=validate                     # Apigee OPDK Org Name

    [x]
    org=xxx-xx-xxxx                  # Apigee X Org ID
```

* Please run below command to authenticate against Apigee X/Hybrid APIS

```
    export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)
```
        
    
## Highlevel Working 
* Export API Proxy Bundle from OPDK instance
* Run Validate API against each Proxy Bundle
* Display JSON Report


## Running
Run the Script as below
```
python3 main.py
```


## Copyright

Copyright 2023 Google LLC. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreement with Google.
