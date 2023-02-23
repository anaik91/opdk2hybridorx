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
        print(f"{dir} already exists")


def list_dir(dir):
    try:
        return os.listdir(dir)
    except FileNotFoundError:
        print(f"Dir {dir} not found")
        sys.exit(1)