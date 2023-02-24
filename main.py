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

from utils import parse_config,create_dir,list_dir
from opdk import ApigeeOPDK
from xorhybrid import ApigeeXorHybrid
import os
import json

def main():
    cfg = parse_config('input.properties')
    skip_export = cfg.getboolean('common','skip_export')
    if not skip_export:
        a=ApigeeOPDK(
            cfg['opdk']['protocol'],
            cfg['opdk']['management_server'],
            cfg['opdk']['management_port'],
            cfg['opdk']['user'],
            cfg['opdk']['password'],
            cfg['opdk']['org'],
        )
        api_revision_map={}
        for each_api in a.list_apis():
            api_revision_map[each_api]=a.list_api_revisions(each_api)[-1]
        create_dir(cfg['common']['export_dir'])
        for k,v in api_revision_map.items():
            print(f"Exporting API : {k} with revision : {v} ")
            a.fetch_api_revision(k,v,cfg['common']['export_dir'])
    else:
        print('Skipping API export !')

    x=ApigeeXorHybrid(cfg['x']['org'])
    x.set_auth_header(os.getenv('APIGEE_ACCESS_TOKEN'))
    proxies=list_dir(cfg['common']['export_dir'])
    result = {}
    for each_bundle in proxies:
        validation=x.validate_api(f"{cfg['common']['export_dir']}/{each_bundle}")
        result[each_bundle]=validation

    print(json.dumps(result,indent=2))

if __name__ == '__main__':
    main()