from utils import parse_config,create_dir,list_dir
from opdk import ApigeeOPDK
from xorhybrid import ApigeeXorHybrid
import os
import json

def main():
    cfg = parse_config('input.properties')
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

    x=ApigeeXorHybrid(cfg['x']['org'])
    x.set_auth_header(os.getenv('APIGEE_ACCESS_TOKEN'))
    # proxies=[ i for i in list_dir(cfg['common']['export_dir']) if '.zip' in i ]
    proxies=list_dir(cfg['common']['export_dir'])
    result = {}
    for each_bundle in proxies:
        validation=x.validate_api(f"{cfg['common']['export_dir']}/{each_bundle}")
        result[each_bundle]=validation

    print(json.dumps(result,indent=2))

if __name__ == '__main__':
    main()