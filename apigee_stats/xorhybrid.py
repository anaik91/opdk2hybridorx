#!/usr/bin/python

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import requests
import os
from requests.utils import quote as urlencode

class ApigeeXorHybrid:
    def __init__(self,org):
        self.baseurl=f"https://apigee.googleapis.com/v1/organizations/{org}"
        self.auth_header = {}

    def set_auth_header(self,token):
        self.auth_header = {
            'Authorization' : f"Bearer {token}"
        }
    
    def list_environments(self):
        url=f"{self.baseurl}/environments"
        response = requests.request("GET", url, headers=self.auth_header)
        if response.status_code == 200 :
            return response.json()
        else:
            return None

    def stats_api(self,env,per_api,select_param,time_range):
        url=f"{self.baseurl}/environments/{env}/stats{'/apiproxy'if per_api else ''}?select={select_param}&timeRange={urlencode(time_range)}"
        response = requests.request("GET", url, headers=self.auth_header)
        if response.status_code == 200 :
            return response.json()
        else:
            return None