# Apigee Stats


## Objective
To get current QPS for a particular Apigee Environment

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
    org=apigee-payg-377208                       # Apigee Organization ID / GCP Project ID 
    env=dev                                      # Apigee Environment Name
    per_api=false                                # Get Per Api Proxy Stats else environment level
    select=tps                                   # Check the links provided below
    timeRange=03/15/2023 00:00~04/04/2023 23:59  # Check the links provided below
```
###
Links 
- [select](https://cloud.google.com/apigee/docs/api-platform/analytics/use-analytics-api-measure-api-program-performance#specifying-the-metrics-to-return)

- [timeRange](https://cloud.google.com/apigee/docs/reference/apis/apigee/rest/v1/organizations.environments.stats/get?apix_params=%7B%22name%22%3A%22organizations%2Fapigee-payg-377208%2Fenvironments%2Fdev%2Fstats%2Fapiproxy%22%2C%22select%22%3A%22tps%22%2C%22timeRange%22%3A%2203%2F15%2F2023%2000%3A00~04%2F03%2F2023%2023%3A59%22%7D#query-parameters)


## Running
Run the Script as below
```
export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)
python3 main.py
```

## Examples

### Example 1 : Metric - TPS
setting below params `input.properties`
``` 
per_api=false
select=tps
```

Output

```{
  "environments": [
    {
      "name": "dev",
      "metrics": [
        {
          "name": "tps",
          "values": [
            "0.006876880849234432"
          ]
        }
      ]
    }
  ],
  ....
}
```


### Example 2 : Metric - Average response time
setting below params `input.properties`
``` 
per_api=true
select=avg(total_response_time)   
```

Output

```
{
  "environments": [
    {
      "name": "dev",
      "dimensions": [
        {
          "name": "az-queue",
          "metrics": [
            {
              "name": "avg(total_response_time)",
              "values": [
                "1094.4444444444446"
              ]
            }
          ]
        },
        {
          "name": "hc",
          "metrics": [
            {
              "name": "avg(total_response_time)",
              "values": [
                "1024.24"
              ]
            }
          ]
        },
  ...
  ...
}
```


## Copyright

Copyright 2023 Google LLC. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreement with Google.
