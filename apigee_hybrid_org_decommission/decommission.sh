#!/bin/bash

INPUTFILE=$1
# OVERRIDES_FILE="$2"

SCRIPT_PATH=$(cat $INPUTFILE | jq -r .script_path)
ORG=$(cat $INPUTFILE | jq -r .project_id)
CASSANDRA_IMAGE=$(cat $INPUTFILE | jq -r .cassandra_client_image)
CASSANDRA_POD_NAME="cassandra-client-$(date +%s)"
DRY_RUN="false"

source $SCRIPT_PATH/helpers/utils.sh
export_path $INPUTFILE
fetch_apigee_org $ORG $SCRIPT_PATH
OVERRIDES_FILE=$HYBRID_HOME/overrides/overrides.yaml
ORG_COUNT=$(cat $GEN_DIR/overrides_data.json | jq -r .org | jq length)

if [ $ORG_COUNT -ne 0 ]; then
    components_ready_check $OVERRIDES_FILE
    delete_apigee_settings $OVERRIDES_FILE "virtualhost" $DRY_RUN
    components_ready_check $OVERRIDES_FILE
    delete_all_apigee_envs $OVERRIDES_FILE $DRY_RUN
    components_ready_check $OVERRIDES_FILE
    delete_apigee_org $OVERRIDES_FILE $DRY_RUN
fi

if [ "$DRY_RUN" == "false" ]; then
    get_keyspaces_to_drop $ORG $SCRIPT_PATH
    run_cql_script $SCRIPT_PATH $CASSANDRA_POD_NAME $CASSANDRA_IMAGE
    restart_cassandra
    components_ready_check $OVERRIDES_FILE
    purge_cassandra_fs_keyspaces_data $ORG
    components_ready_check $OVERRIDES_FILE
fi
