#!/bin/bash

# Copyright 2023 Google LLC
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

export_path() {
    PROJECT_ID="$(cat $1 | jq -r .project_id)"
    HYBRID_HOME="${HOME}/$(cat $1 | jq -r .apigeectl_installation)/hybrid-files" 
    APIGEECTL_HOME="${HOME}/$(cat $1 | jq -r .apigeectl_installation)/apigeectl"
    APIGEECTL_ROOT="${HOME}/$(cat $1 | jq -r .apigeectl_installation)"
    QUICKSTART_TOOLS=$HOME
    # ISTIO_CTL=$QUICKSTART_TOOLS/asm/istio-1.9.8-asm.6
    export PATH=$PATH:"$QUICKSTART_TOOLS"/kpt
    export PATH=$PATH:"$QUICKSTART_TOOLS"/jq
    export PATH=$ISTIO_CTL/bin:$PATH
    export PATH=$PATH:$APIGEECTL_HOME
    # source "$HOME/google-cloud-sdk/path.bash.inc"
    # source "$HOME/google-cloud-sdk/completion.bash.inc"
    # echo ${GOOGLE_CREDENTIALS} > /tmp/GOOGLE_CREDENTIALS
    # SERVICE_ACCOUNT=$(cat /tmp/GOOGLE_CREDENTIALS | jq -r .client_email)
    # gcloud auth activate-service-account $SERVICE_ACCOUNT \
    #             --key-file=/tmp/GOOGLE_CREDENTIALS --project=$PROJECT_ID
    # gcloud config set project $PROJECT_ID
}

function wait_for_ready(){
    local expected_output=$1
    local action=$2
    local message=$3
    local max_iterations=150 # 10min
    local iterations=0
    local actual_out

    echo -e "Waiting for $action to return output $expected_output"
    echo -e "Start: $(date)\n"

    while true; do
        iterations="$((iterations+1))"

        actual_out=$(bash -c "$action" || echo "error code $?")
        echo -e "actual_out->\n$actual_out" 
        if [ "$expected_output" = "$actual_out" ]; then
            echo -e "\n$message"
            break
        fi

        if [ "$iterations" -ge "$max_iterations" ]; then
          echo "Wait timed out"
          exit 1
        fi
        echo -n "."
        sleep 5
    done
}

function wait_for_exit0(){
  command=$1
  until
    bash -c "$command"
    [ "$?" -eq 0 ]
  do
    echo Try again
    sleep 5
  done
}

check_rs_ds_sts_pods() {
    namespace=$1
    kind=$2
    object_name=$3
    if [[ "$kind" == "sts" || "$kind" == "statefulset" || "$kind" == "rs" || "$kind" == "replicaset" ]] ; then
    sts_replicas=$(kubectl get \
        $kind \
        -n $namespace \
        $object_name \
        -o=json | \
        jq -r .status.replicas)
    wait_for_ready \
        $sts_replicas \
        "kubectl get $kind -n $namespace $object_name -o=json | jq -r .status.readyReplicas" "All $object_name Pods Are UP"
    
    elif [[ "$kind" == "ds" || "$kind" == "daemonset"  ]] ; then

    sts_replicas=$(kubectl get \
        $kind \
        -n $namespace \
        $object_name \
        -o=json | \
        jq -r .status.desiredNumberScheduled )
    wait_for_ready \
        $sts_replicas \
        "kubectl get  $kind -n $namespace $object_name -o=json | jq -r .status.numberReady" "All $object_name Pods Are UP"

    else 
        echo "Unknown Kubernetes Kind  : ----> $kind ... !!!"
        exit 1
    fi
}

# Create Kubernetes secret for certificates
create_secret_cert(){
  egn=$1
  cluster=$2
  kubectl create -n istio-system secret tls $egn-ssl-secret --kubeconfig=$cluster \
    --key=$HYBRID_HOME/certs/$egn.key \
    --cert=$HYBRID_HOME/certs/$egn.pem
}

# Retrieve token 
token() { echo -n "$(gcloud config config-helper --force-auth-refresh | grep access_token | grep -o -E '[^ ]+$')" ; }

#Enable APIs
enable_all_apis() {

  echo "📝 Enabling all required APIs in GCP project \"$PROJECT_ID\""
  echo -n "⏳ Waiting for APIs to be enabled"

  gcloud services enable \
    apigee.googleapis.com \
    apigeeconnect.googleapis.com \
    cloudresourcemanager.googleapis.com \
    pubsub.googleapis.com \
    cloudresourcemanager.googleapis.com \
    compute.googleapis.com \
    container.googleapis.com --project $PROJECT_ID


  gcloud config set project $PROJECT_ID
}

# Check CA cert secrets
check_ssl_secret(){
   env_group_name=$1
   cluster=$2
   domain=$3
   secret_response=$(kubectl get secret -n istio-system -o=json --kubeconfig=$cluster | jq --arg secret "$env_group_name-ssl-secret" -r '.items[] | select(.metadata.name | contains($secret))')
   if [[ -z $secret_response ]] ; then
     echo "🤷‍♀️ Secret Doesnt Exist !! 🔧 Creating Secret $env_group_name"
     openssl req  -nodes -new -x509 -keyout $HYBRID_HOME/certs/$env_group_name.key -out $HYBRID_HOME/certs/$env_group_name.pem -subj '/CN='*.$domain'' -days 3650
     create_secret_cert $env_group_name $cluster
   else
     echo "🎉 Secret $1 Already Exists !!"
   fi 
}

# Check if service account exists
check_for_sa() {
    if [[ "$ENV" == "non-prod" ]]; then
      echo "🤔 Checking required service account $ENV"
        if (gcloud iam service-accounts describe apigee-non-prod@$PROJECT_ID.iam.gserviceaccount.com) &>/dev/null;then
         echo "🎉 Service account exists"
         return 0
        else
         echo "💣 Service account doesnt exist. Please create sa!! Exiting"
         return 1
        fi
    else
      echo "🤔 Checking required service account $ENV ⏳"
      flag=1
       saNames=(apigee-cassandra apigee-logger apigee-mart apigee-metrics apigee-runtime apigee-synchronizer apigee-udca apigee-watcher)
       for sa in ${saNames[@]}
        do
         if ( ! gcloud iam service-accounts describe $sa@$PROJECT_ID.iam.gserviceaccount.com) &>/dev/null;then
           echo "💣 Service Account - $sa doesn't exist"
           flag=0
         fi
        done
      if [[ $flag == 0 ]]; then
        echo "📥 You need to create service accounts to continue. Exiting"
        return 1
       else
        return 0
      fi
    fi 
}

check_k8s_object() {
  cluster=$1
  obj=$2
  name=$3
  ns=$4

  if [[ "$obj" == "namespace" || "$obj" == "ns"  ]] ; then
    obj_response=$(kubectl get $obj -o=json --kubeconfig=$cluster | jq --arg obj "$name" -r '.items[] | select(.metadata.name | contains($obj))')
    if [[ -z $obj_response ]] ; then
    return 1
    else
    return 0
    fi
  else
    obj_response=$(kubectl get $obj -n $ns -o=json --kubeconfig=$cluster | jq --arg obj "$name" -r '.items[] | select(.metadata.name | contains($obj))')
    if [[ -z $obj_response ]] ; then
    return 1
    else
    return 0
    fi
  fi
}

validate_cluster() {
    wait_for_ready "Running" "kubectl get po -l app=$1 -n $2 -o=jsonpath='{.items[0].status.phase}' 2>/dev/null" "$1: Running"
}

deploy_api() {
    api_proxy_name="mock"
    proxy_bundle_file="mock_rev1_2021_12_30.zip"
    for ENV_GROUP_NAME in $ENVGPARR
    do
     envnames=$(cat $INPUTFILE | jq -r  .apigee_envgroups.$ENV_GROUP_NAME.environments[])
          for envname in $envnames
           do
            python3 $SCRIPT_PATH/python/deploy_api.py \
                --project_id $PROJECT_ID \
                --api_proxy_name $api_proxy_name \
                --proxy_bundle_path $SCRIPT_PATH/api_proxy_bundle/$proxy_bundle_file \
                --env $envname
            done
    done
}

validate_api() {
    client_pod_name=$(date +%s)
    client_pod_spec="/tmp/validate_client.yaml"
    sed "s*<VALIDATION_IMAGE>*$VALIDATION_IMAGE*;s*<date>*${client_pod_name}*;s*<VALIDATION_IMAGE_PULL_SECRET>*$VALIDATION_IMAGE_PULL_SECRET*" $SCRIPT_PATH/templates/validate_client.yaml > ${client_pod_spec}
    kubectl apply -f ${client_pod_spec}
    for ENV_GROUP_NAME in $ENVGPARR
     do
      hostnames=$(cat $INPUTFILE | jq -r  .apigee_envgroups.$ENV_GROUP_NAME.hostnames[])
      tlsmode=$(cat $INPUTFILE | jq -r  .apigee_envgroups.$ENV_GROUP_NAME.tls_mode)
      if [[ "$tlsmode" = "SIMPLE" ]]; then
       for hostname in $hostnames
         do
           HOSTALIAS=$hostname
           export INGRESS_HOST=$(kubectl -n istio-system get service \
           istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
           export SECURE_INGRESS_PORT=$(kubectl -n istio-system get \
           service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
           expected_output=$(curl https://mocktarget.apigee.net/json)
           wait_for_ready "$expected_output" \
           "kubectl exec curl-$client_pod_name -n apigee -- curl -H Host:$HOSTALIAS --resolve $HOSTALIAS:$SECURE_INGRESS_PORT:$INGRESS_HOST https://$HOSTALIAS:$SECURE_INGRESS_PORT/mock -k" \
           "API Proxy Validation Successful"
          done
       else
          echo " Change tls_mode value to SIMPLE instead of MUTUAL" 
     fi          
    done
     kubectl delete -f ${client_pod_spec} 
}

check_cassandra_pods() {
  cassandra_desired_replicas=$(kubectl get \
    sts \
    -n apigee \
    apigee-cassandra-default \
    -o=json | \
    jq -r .status.replicas)
  wait_for_ready $cassandra_desired_replicas "kubectl get sts -n apigee apigee-cassandra-default -o=json | jq -r .status.readyReplicas" "All Cassandra Pods Are UP"

}

check_apigeedatastore() {
  wait_for_ready "running" "kubectl get apigeeds default -n apigee -o=json | jq -r .status.state" "ApigeeDatastore is running"
}

cassandra_replication() {
    replication_manifest=$1
    kubectl apply -f $replication_manifest
    sleep 2 && echo -n "Waiting for datareplication apply"
    wait_for_ready "complete" "kubectl -n apigee get apigeeds -o json | jq -r '.items[].status.cassandraDataReplication.rebuildDetails.\"apigee-cassandra-default-0\".state'" "Replication completed !!"
    echo  "Data replicaiton completed!"
}

apply_operational_change(){
  overrides=$1
  flag=$2
  pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
  mkdir -p "$HYBRID_HOME"/generated
  echo "Applying changes!!"
  echo ""$APIGEECTL_HOME"/apigeectl apply -f $overrides $flag"
  "$APIGEECTL_HOME"/apigeectl apply -f $overrides $flag --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl apply -f $overrides $flag --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml )
  sleep 2 && echo -n "Waiting for Apigeectl apply"
  echo "Update Completed"
  popd || return
}

verify_backup_restore(){
    backup_enabled="$(cat $INPUTFILE | jq -r .cassandra_backup.enabled)"
    restore_enabled="$(cat $INPUTFILE | jq -r .cassandra_restore.enabled)"
    if [[ "$backup_enabled" == "true" ]]; then 
      echo "Backup parameter is enabled. Checking Backup Status !!"
      download_cluster_version_kubectl $cluster_kubectl_location
      job_name="backup-trigger-$(date +%s)"
      $cluster_kubectl_location create job --from=cronjob/apigee-cassandra-backup -n apigee $job_name
      wait_for_ready "Succeeded" "kubectl get pod -n apigee -l job-name=$job_name -o json | jq -r '.items[0].status.phase'" "Backup job is completed !!"
      kubectl delete job $job_name -n apigee
    elif [[ "$restore_enabled" == "true" ]]; then
      echo "Backup is not enabled !! Checking Restore Parameter !!"
      echo "Restore parameter is enabled. Checking Restore Status !!"
      wait_for_ready "Succeeded" "kubectl get pod -n apigee -l job-name=apigee-cassandra-restore -o json| jq -r '.items[0].status.phase'" "Restore job is completed !!"
    else
      echo "Backup and Restore both are disabled"
    fi
}

download_cluster_version_kubectl() {
    kubectl_location=$1
    k8s_server_version=$(kubectl version -o=json | jq -r .serverVersion.gitVersion)
    curl -LO "https://dl.k8s.io/release/$k8s_server_version/bin/linux/amd64/kubectl"
    mv kubectl ${kubectl_location}
    chmod +x ${kubectl_location}
}


delete_apigee_env_components(){
  overrides=$1
  env=$2
  if [ -z "$env" ]; then
    echo "Environment param is empty !! "
    exit 1
  fi
  pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
  mkdir -p "$HYBRID_HOME"/generated
  echo "Deleting Environment  $env!!"
  echo ""$APIGEECTL_HOME"/apigeectl delete -f $overrides --env=$env"
  "$APIGEECTL_HOME"/apigeectl delete -f $overrides --env=$env --dry-run=client
  if [ $? -eq 0 ]; then
  "$APIGEECTL_HOME"/apigeectl delete -f $overrides --env=$env --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl delete -f $overrides --env=$env --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml )
  sleep 2 && echo -n "Waiting for Apigeectl delete"
  fi
  echo "Delete of Environment $env Completed"
  popd || return
}

delete_apigee_settings(){
  overrides=$1
  settings=$2
  dry_run="${3:-false}"
  if [ -z "$settings" ]; then
    echo "setting param is empty !! "
    exit 1
  fi
  pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
  mkdir -p "$HYBRID_HOME"/generated
  echo "Deleting settings  $settings!!"
  echo ""$APIGEECTL_HOME"/apigeectl delete -f $overrides --settings $settings"
  if [ "$dry_run" == "true" ]; then
    "$APIGEECTL_HOME"/apigeectl delete -f $overrides --settings $settings --dry-run=client
    return
  else
    "$APIGEECTL_HOME"/apigeectl delete -f $overrides --settings $settings --dry-run=client
  fi
  if [ $? -eq 0 ]; then
  "$APIGEECTL_HOME"/apigeectl delete -f $overrides --settings $settings --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl delete -f $overrides --settings $settings --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml )
  sleep 2 && echo -n "Waiting for Apigeectl delete"
  fi
  echo "Delete of settings $settings Completed"
  popd || return
}

delete_all_apigee_envs(){
  overrides=$1
  dry_run="${2:-false}"
  pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
  mkdir -p "$HYBRID_HOME"/generated
  echo "Deleting Environments !!"
  echo ""$APIGEECTL_HOME"/apigeectl delete -f $overrides --all-envs"
  if [ "$dry_run" == "true" ]; then
    "$APIGEECTL_HOME"/apigeectl delete -f $overrides --all-envs --dry-run=client
    return
  else
    "$APIGEECTL_HOME"/apigeectl delete -f $overrides --all-envs --dry-run=client
  fi
  if [ $? -eq 0 ]; then
  "$APIGEECTL_HOME"/apigeectl delete -f $overrides --all-envs --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl delete -f $overrides --all-envs --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml )
  sleep 2 && echo -n "Waiting for Apigeectl delete"
  fi
  echo "Delete of Environments Completed"
  popd || return
}

delete_apigee_org(){
  overrides=$1
  dry_run="${2:-false}"
  pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
  mkdir -p "$HYBRID_HOME"/generated
  echo "Deleting Organization !!"
  echo ""$APIGEECTL_HOME"/apigeectl delete -f $overrides --org"
  if [ "$dry_run" == "true" ]; then
    "$APIGEECTL_HOME"/apigeectl delete -f $overrides --org --dry-run=client
    return
  else
    "$APIGEECTL_HOME"/apigeectl delete -f $overrides --org --dry-run=client
  fi
  if [ $? -eq 0 ]; then
  "$APIGEECTL_HOME"/apigeectl delete -f $overrides --org --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl delete -f $overrides --org --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml )
  sleep 2 && echo -n "Waiting for Apigeectl delete"
  fi
  echo "Delete of Organization Completed"
  popd || return
}

components_ready_check(){
  pushd "$HYBRID_HOME"
  overrides=$1
  command="$APIGEECTL_HOME/apigeectl check-ready -f $overrides"
  wait_for_exit0 "$command"
  popd || return
}

get_keyspaces_to_drop() {
  ORG=$1
  SCRIPT_PATH="$2"
  APIGEE_ORG=$(echo "$ORG" | tr '-' '_')
  GEN_DIR="$SCRIPT_PATH/generated"
  KEYSPACES_FILE="$GEN_DIR/keyspaces.txt"
  kubectl \
    exec \
    -it -n \
    apigee \
    apigee-cassandra-default-0 \
    -- find /opt/apigee/data/apigee-cassandra/ -iname "*${APIGEE_ORG}_hybrid" -type d -maxdepth 2 -printf "%f\n" > $KEYSPACES_FILE
}

create_cassandra_client() {
  SCRIPT_PATH="$1"
  CASSANDRA_POD_NAME="$2"
  CASSANDRA_IMAGE_NAME="$3"
  CASSANDRA_CRED_SECRET="$4"
  CASSANDRA_TLS_SECRET="$5"
  APIGEE_ORG=$(echo "$ORG" | tr '-' '_')
  GEN_DIR="$SCRIPT_PATH/generated"
  CASSANDRA_POD_SPEC="cassandra-client-$(date +%s).yaml"
  cat <<EOT >> $GEN_DIR/$CASSANDRA_POD_SPEC
apiVersion: v1
kind: Pod
metadata:
  labels:
  name: $CASSANDRA_POD_NAME
  namespace: apigee
spec:
  containers:
  - name: cassandra-client-name
    image: "$CASSANDRA_IMAGE_NAME"
    imagePullPolicy: Always
    command:
    - sleep
    - "3600"
    env:
    - name: CASSANDRA_SEEDS
      value: apigee-cassandra-default.apigee.svc.cluster.local
    - name: APIGEE_DDL_USER
      valueFrom:
        secretKeyRef:
          key: ddl.user
          name: $CASSANDRA_CRED_SECRET
    - name: APIGEE_DDL_PASSWORD
      valueFrom:
        secretKeyRef:
          key: ddl.password
          name: $CASSANDRA_CRED_SECRET
    volumeMounts:
    - mountPath: /opt/apigee/ssl
      name: tls-volume
      readOnly: true
  volumes:
  - name: tls-volume
    secret:
      defaultMode: 420
      secretName: $CASSANDRA_TLS_SECRET
  restartPolicy: Never
EOT
  echo "Creating Cassandra Pod"
  kubectl apply -f $GEN_DIR/$CASSANDRA_POD_SPEC
  kubectl wait --for=condition=ready pod $CASSANDRA_POD_NAME -n apigee
}

run_cql_script() {
  SCRIPT_PATH="$1"
  GEN_DIR="$SCRIPT_PATH/generated"
  CASSANDRA_POD_NAME="$2"
  CASSANDRA_IMAGE_NAME="$3"
  KEYSPACES_FILE="$GEN_DIR/keyspaces.txt"
  NAMESPACE="apigee"
  CQL_SCRIPT="$GEN_DIR/cql_op.sh"
  CASSANDRA_CQL_SCRIPT_PATH="/tmp/cql_op.sh"
  CASSANDRA_KEYSPACES_PATH="/tmp/keyspaces"
  CASSANDRA_CRED_SECRET="apigee-datastore-default-creds"
  CASSANDRA_TLS_SECRET=$(kubectl get secret \
    -n apigee \
    -o jsonpath='{.items[?(@.metadata.annotations.cert-manager\.io\/certificate-name=="apigee-cassandra-default")].metadata.name}')
  create_cassandra_client $SCRIPT_PATH $CASSANDRA_POD_NAME $CASSANDRA_IMAGE_NAME $CASSANDRA_CRED_SECRET $CASSANDRA_TLS_SECRET
  echo "Creating Cassandra drop Script"
  cat <<EOT >> $CQL_SCRIPT
#!/bin/bash
set -e
for ks in \$(cat /tmp/keyspaces)
do
  echo "dropping keyspace \$ks"
  cqlsh \${CASSANDRA_SEEDS} -u \${APIGEE_DDL_USER} -p \${APIGEE_DDL_PASSWORD} --ssl -e "drop keyspace \$ks"
done
echo "Operation finished !!"
EOT
  echo "Copying Cassandra drop Script to Cassandra Pod : $CASSANDRA_POD_NAME"
  kubectl cp $CQL_SCRIPT "$NAMESPACE/$CASSANDRA_POD_NAME:$CASSANDRA_CQL_SCRIPT_PATH"
  kubectl cp $KEYSPACES_FILE "$NAMESPACE/$CASSANDRA_POD_NAME:$CASSANDRA_KEYSPACES_PATH"
  echo "Executing Cassandra drop Script on Cassandra Pod : $CASSANDRA_POD_NAME"
  kubectl exec -n "$NAMESPACE" "$CASSANDRA_POD_NAME" -- bash "$CASSANDRA_CQL_SCRIPT_PATH"
  echo "Deleting Cassandra Pod : $CASSANDRA_POD_NAME"
  kubectl delete pod -n "$NAMESPACE" "$CASSANDRA_POD_NAME"
}

restart_cassandra() {
  kubectl rollout restart statefulset -n apigee apigee-cassandra-default
  check_cassandra_pods
}

purge_cassandra_fs_keyspaces_data() {
  ORG=$1
  APIGEE_ORG=$(echo "$ORG" | tr '-' '_')
  for cass_pod in $(kubectl get pods -n apigee -l app=apigee-cassandra -o jsonpath='{.items[*].metadata.name}')
  do
    kubectl wait --for=condition=ready pod $cass_pod -n apigee
    echo "Cleaning Pod -> $cass_pod"
    kubectl exec -it -n apigee $cass_pod -- find /opt/apigee/data/apigee-cassandra/ -iname "*${APIGEE_ORG}_hybrid" -type d -maxdepth 2 -exec rm -rf {} +
    sleep 2
  done
}

fetch_apigee_org() {
  PROJECT_ID="$1"
  SCRIPT_PATH="$2"
  GEN_DIR="$SCRIPT_PATH/generated"
  mkdir -p $GEN_DIR
  ORG_DATA=$(kubectl get apigeeorg -n apigee -o json | jq -c --arg prj "$PROJECT_ID" -r '.items[] | select(.spec.gcpProjectID==$prj)')
  if [ -z "$ORG_DATA" ]; then ORG_DATA="{}"; fi
  ENC_ORG=$(echo $ORG_DATA| jq -r .metadata.name)
  ENV_DATA=$(kubectl get apigeeenv -n apigee -o json | jq -c --arg prj "$ENC_ORG" -r '[.items[] | select(.spec.organizationRef==$prj)]')
  VHOSTS_DATA=$(kubectl get ar -n apigee -o json | jq -c --arg prj "$PROJECT_ID" -r '[.items[] | select(.metadata.labels.org==$prj)]')
  overrides_data=$(jq -n \
              --argjson org "$ORG_DATA" \
              --argjson envs "$ENV_DATA" \
              --argjson virtualhosts "$VHOSTS_DATA" \
              '$ARGS.named'
  )
  echo $overrides_data | jq  > $GEN_DIR/overrides_data.json
  org_exists=$(echo $overrides_data | jq -r .org | jq length)
  if [ "$org_exists" -eq 0 ]; then
    echo "Apigee Org -> $ENC_ORG with PROJECT_ID : $PROJECT_ID not found in cluster or may have been deleted !"
  else
    echo "Apigee Org -> $ENC_ORG with PROJECT_ID : $PROJECT_ID found !"
    echo "Generating overrides.yaml"
    python3 $SCRIPT_PATH/helpers/generate_overrides.py \
        --input_file $GEN_DIR/overrides_data.json  \
        --output_file $GEN_DIR/overrides.yaml \
        --template_location $SCRIPT_PATH/helpers
    cp "$GEN_DIR/overrides.yaml" $HYBRID_HOME/overrides/overrides.yaml
  fi
}
