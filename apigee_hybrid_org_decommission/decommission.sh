#!/bin/bash

INPUTFILE=$1
# OVERRIDES_FILE="$2"

SCRIPT_PATH=$(cat $INPUTFILE | jq -r .script_path)
ORG=$(cat $INPUTFILE | jq -r .project_id)
CASSANDRA_IMAGE=$(cat $INPUTFILE | jq -r .cassandra_client_image)
CASSANDRA_POD_NAME="cassandra-client-$(date +%s)"
source $SCRIPT_PATH/utils.sh

fetch_apigee_org $ORG $SCRIPT_PATH
GEN_DIR="$SCRIPT_PATH/generated"


export_path $INPUTFILE
cp "$GEN_DIR/overrides.yaml" $HYBRID_HOME/overrides/overrides.yaml
OVERRIDES_FILE=$HYBRID_HOME/overrides/overrides.yaml

components_ready_check $OVERRIDES_FILE
exit 0
delete_apigee_settings $OVERRIDES_FILE "virtualhost"

components_ready_check $OVERRIDES_FILE

delete_all_apigee_envs $OVERRIDES_FILE

components_ready_check $OVERRIDES_FILE

delete_apigee_org $OVERRIDES_FILE

get_keyspaces_to_drop $ORG

run_cql_script $CASSANDRA_POD_NAME $CASSANDRA_IMAGE

restart_cassandra

components_ready_check $OVERRIDES_FILE

purge_cassandra_fs_keyspaces_data $ORG

components_ready_check $OVERRIDES_FILE