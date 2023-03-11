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

import sys
import os
import json
import yaml
import jinja2
import argparse

def read_file(file):
    if os.path.exists(file):
        with open(file) as fl:
            data=fl.read()
            return data
    else:
        print('ERROR : File {} doesnt exist .'.format(file))
        sys.exit(1)

def check_path(file):
    path_dir = '/'.join(file.split('/')[:-1])
    if os.path.exists(path_dir):
        if os.path.exists(file):
            print('INFO : File {} already exists ! overwriting it !!! '.format(file))
    else:
        print('ERROR : Path {} doesnt exist .'.format(path_dir))
        sys.exit(1)


def write_file(file,data):
    check_path(file)
    with open(file,'w') as fl:
        fl.write(data)

def parse_json(file):
    data=read_file(file)
    try:
        json_data=json.loads(data)
        return json_data
    except json.decoder.JSONDecodeError:
        print('ERROR : File {} is not valid JSON'.format(file))
        sys.exit(1)

def read_jinja_template(template_file,template_path):
    templateLoader = jinja2.FileSystemLoader(searchpath=template_path)
    templateEnv = jinja2.Environment(loader=templateLoader)
    template = templateEnv.get_template(template_file)
    return template

def print_yaml(data):
    print(yaml.dump(yaml.load(data, Loader=yaml.FullLoader)))

def write_yaml(file,data):
    check_path(file)
    with open(file, 'w') as outfile:
        yaml.dump(
            yaml.load(data, Loader=yaml.FullLoader), 
            outfile, 
            default_flow_style=False,
            sort_keys=False
        )

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_file", help="Location to input_file",
                        type=str,required=True)
    parser.add_argument("--output_file", help="Location to store overrides.yaml file",
    type=str,required=True)
    parser.add_argument("--template_location", help="Absolute Location Having jinja temaplate",
    type=str,required=True)
    args = parser.parse_args()
    input_file = args.input_file
    template=read_jinja_template('overrides.j2',args.template_location)
    input_data = parse_json(input_file)
    outputText = template.render(input_data)
    write_yaml(args.output_file,outputText)

if __name__ == '__main__' :
    main()