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
    stats=x.stats_api(
        env,
        per_api,
        select,
        timeRange
    )
    print_json(stats)

if __name__ == '__main__':
    main()