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

def parse_config(config_file):
    config = configparser.ConfigParser()
    config.read(config_file)
    return config

def create_dir(dir):
    try:
        os.makedirs(dir)
    except FileExistsError:
        print(f"INFO: {dir} already exists")

def list_dir(dir):
    try:
        return os.listdir(dir)
    except FileNotFoundError:
        print(f"ERROR: Directory \"{dir}\" not found")
        sys.exit(1)