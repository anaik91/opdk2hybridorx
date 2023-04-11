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

from utils import parse_config,get_access_token,print_json
from xorhybrid import ApigeeXorHybrid


def main():
    cfg = parse_config('input.properties')
    org = cfg.get('common','org')
    env = cfg.get('common','env')
    select = cfg.get('common','select')
    timeRange = cfg.get('common','timeRange')
    per_api = cfg.getboolean('common','per_api')
    
    x=ApigeeXorHybrid(org)
    x.set_auth_header(get_access_token())
    if env == '_ALL_':
        envs = x.list_environments()
    else:
        true_envs = x.list_environments()
        input_envs = env.split(',')
        envs = [ env for env in input_envs if  env in true_envs ]
        if len(envs) < len(input_envs):
            print('INFO: Skipped Invalid Orgs !')
    result = {}
    for each_env in envs:
        stats=x.stats_api(
            each_env,
            per_api,
            select,
            timeRange
        )
        result[each_env]= stats['environments'][0] if len(stats['environments'])>0 else {}
    print_json(result)

if __name__ == '__main__':
    main()