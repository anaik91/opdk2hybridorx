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
    api_types = ['apis','sharedflows']
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
        for each_api_type in api_types:
            api_revision_map[each_api_type]={}
            api_revision_map[each_api_type]['proxies']={}
            api_revision_map[each_api_type]['export_dir']=cfg['common']['export_dir']+f'/{each_api_type}'
            create_dir(cfg['common']['export_dir']+f'/{each_api_type}')

            for each_api in a.list_apis(each_api_type):
                api_revision_map[each_api_type]['proxies'][each_api]=a.list_api_revisions(each_api_type,each_api)[-1]
        for each_api_type,each_api_type_data in api_revision_map.items():
            for each_api,each_api_rev in each_api_type_data['proxies'].items():
                print(f"Exporting API : {each_api} with revision : {each_api_rev} ")
                a.fetch_api_revision(each_api_type,each_api,each_api_rev,api_revision_map[each_api_type]['export_dir'])
    else:
        print('Skipping API export !')

    x=ApigeeXorHybrid(cfg['x']['org'])
    x.set_auth_header(os.getenv('APIGEE_ACCESS_TOKEN'))
    result = {}
    for each_api_type in api_types:
        export_dir = cfg['common']['export_dir']+f'/{each_api_type}'
        proxies=list_dir(export_dir)
        result[each_api_type] = {}
        for each_bundle in proxies:
            validation=x.validate_api(f"{export_dir}/{each_bundle}")
            result[each_api_type][each_bundle]=validation

    print(json.dumps(result,indent=2))

if __name__ == '__main__':
    main()