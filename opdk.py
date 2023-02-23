import requests
import base64
import shutil

class ApigeeOPDK:
    def __init__(self,protocol,management_server,
    management_port,user,password,org):
        self.protocol=protocol
        self.management_server=management_server
        self.management_port=management_port
        self.user=user
        self.password=password
        self.org=org

    def get_auth_header(self):
        value=base64.b64encode(f"{self.user}:{self.password}".encode('ascii'))
        return {
            'Authorization' : f"Basic {value.decode('utf-8')}"
        }
    
    def list_apis(self):
        url = f"{self.protocol}://{self.management_server}:{self.management_port}/v1/o/{self.org}/apis"
        headers = self.get_auth_header()
        r=requests.get(url,headers=headers)
        if r.status_code == 200:
            return r.json()
    
    def list_api_revisions(self,api_name):
        url = f"{self.protocol}://{self.management_server}:{self.management_port}/v1/o/{self.org}/apis/{api_name}/revisions"
        headers = self.get_auth_header()
        r=requests.get(url,headers=headers)
        if r.status_code == 200:
            return r.json()
    
    def fetch_api_revision(self,api_name,revision,export_dir):
        url = f"{self.protocol}://{self.management_server}:{self.management_port}/v1/o/{self.org}/apis/{api_name}/revisions/{revision}?format=bundle"
        headers = self.get_auth_header()
        r=requests.get(url,headers=headers, stream=True)
        if r.status_code == 200:
            self.write_proxy_bundle(export_dir,api_name,r.raw)
            return True
    
    def write_proxy_bundle(self,export_dir,file_name,data):
        file_path = f"./{export_dir}/{file_name}.zip"
        with open(file_path,'wb') as fl:
            shutil.copyfileobj(data, fl)
