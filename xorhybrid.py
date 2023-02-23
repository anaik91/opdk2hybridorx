import requests
import os

class ApigeeXorHybrid:
    def __init__(self,org):
        self.baseurl=f"https://apigee.googleapis.com/v1/organizations/{org}"
        self.auth_header = {}

    def set_auth_header(self,token):
        self.auth_header = {
            'Authorization' : f"Bearer {token}"
        }
    
    def validate_api(self,proxy_bundle_path):
        api_name = os.path.basename(proxy_bundle_path).split('.zip')[0]
        url = f"{self.baseurl}/apis?name={api_name}&action=validate&validate=true"
        files=[
        ('data',(api_name,open(proxy_bundle_path,'rb'),'application/zip'))
        ]
        response = requests.request("POST", url, headers=self.auth_header, data={}, files=files)
        if response.status_code == 200 :
            return True
        else:
            return response.json()