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

import configparser
import os
import sys
import requests
import json

def parse_config(config_file):
    config = configparser.ConfigParser()
    config.read(config_file)
    return config

def is_token_valid(token):
    url=f"https://www.googleapis.com/oauth2/v1/tokeninfo?access_token={token}"
    r=requests.get(url)
    if r.status_code==200:
        print(f"Token Validated for user {r.json()['email']}")
        return True
    return False

def get_access_token():
    token=os.getenv('APIGEE_ACCESS_TOKEN')
    if token is not None:
        if is_token_valid(token):
            return token
    print('please run "export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)" first !! ')
    sys.exit(1)

def print_json(data):
    print(json.dumps(data,indent=2))