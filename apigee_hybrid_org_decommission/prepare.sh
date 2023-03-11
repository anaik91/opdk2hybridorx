#!/bin/bash

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

INPUTFILE=$1

########### Function Definitions ###########
install_packages() {
    if cat /etc/*release | grep ^NAME | grep 'CentOS\|Red\|Fedora'; then
    echo "==============================================="
    echo "Installing packages $1 on RPM based OS"
    echo "==============================================="
    yum install -y $1

 elif cat /etc/*release | grep ^NAME | grep 'Ubuntu\|Debian\|Mint\|Knoppix'; then
    echo "==============================================="
    echo "Installing packages $1 on apt based OS"
    echo "==============================================="
    apt-get update
    apt-get install -y $1

 else
    echo "OS NOT DETECTED, couldn't install package $1"
    exit 1;
 fi
}
set_config_params() {
    set -e
    #ENV=$(cat ./tmp/input.json | jq -r .env ) 
    #CERT_TYPE=$(cat ./tmp/input.json | jq -r .ca_cert)  
    HYBRID_HOME="${HOME}/$(cat $1 | jq -r .apigeectl_installation)/hybrid-files" 
    APIGEECTL_HOME="${HOME}/$(cat $1 | jq -r .apigeectl_installation)/apigeectl"
    APIGEECTL_ROOT="${HOME}/$(cat $1 | jq -r .apigeectl_installation)"
    
    QUICKSTART_TOOLS=$HOME
    PROJECT_ID=$(cat $1 | jq -r .project_id) 
    SCRIPT_PATH=$(cat $INPUTFILE | jq -r .script_path)
    #envgparr=$(cat ./tmp/input.json | jq -r '.apigee_envgroups | keys[]')
    export APIGEE_CTL_VERSION="$(cat $1 | jq -r .apigeectl_version)"
    echo "- Apigeectl version $APIGEE_CTL_VERSION"
    export KPT_VERSION='v0.34.0'
    echo "- kpt version $KPT_VERSION"
    # export CERT_MANAGER_VERSION="$(cat $1 | jq -r .cert_mg_version)"
    # echo "- Cert Manager version $CERT_MANAGER_VERSION"
    # export ASM_VERSION="$(cat $1 | jq -r .asm_version)"
    # echo "- ASM version $ASM_VERSION"
    OS_NAME=$(uname -s)
    if [[ "$OS_NAME" == "Linux" ]]; then
      echo "- 🐧 Using Linux binaries"
      export APIGEE_CTL='apigeectl_linux_64.tar.gz'
      export KPT_BINARY='kpt_linux_amd64-0.34.0.tar.gz'
      export JQ_VERSION='jq-1.6/jq-linux64'
    elif [[ "$OS_NAME" == "Darwin" ]]; then
      echo "- 🍏 Using macOS binaries"
      export APIGEE_CTL='apigeectl_mac_64.tar.gz'
      export KPT_BINARY='kpt_darwin_amd64-0.34.0.tar.gz'
      export JQ_VERSION='jq-1.6/jq-osx-amd64'
    else
      echo "💣 Only Linux and macOS are supported at this time. You seem to be running on $OS_NAME."
      exit 2
    fi
}

install_asm() {
  echo "🏗️ Preparing ASM install requirements"
  mkdir -p "$QUICKSTART_TOOLS"/kpt
  curl --fail -L -o "$QUICKSTART_TOOLS/kpt/kpt.tar.gz" "https://github.com/GoogleContainerTools/kpt/releases/download/${KPT_VERSION}/${KPT_BINARY}"
  tar xzf "$QUICKSTART_TOOLS/kpt/kpt.tar.gz" -C "$QUICKSTART_TOOLS/kpt"
  export PATH=$PATH:"$QUICKSTART_TOOLS"/kpt

  echo "🏗️ Installing Anthos Service Mesh"
  mkdir -p "$QUICKSTART_TOOLS"/asm
  curl --fail -L -o "$QUICKSTART_TOOLS/asm/asm.tar.gz" "https://storage.googleapis.com/gke-release/asm/istio-${ASM_VERSION}-linux-amd64.tar.gz"
  tar xzf "$QUICKSTART_TOOLS/asm/asm.tar.gz" -C "$QUICKSTART_TOOLS/asm"
  ISTIO_CTL=$QUICKSTART_TOOLS/asm/istio-$ASM_VERSION
  export PATH=$ISTIO_CTL/bin:$PATH
  echo "✅ ASM installed"
}

download_apigee_ctl() {
    echo "📥 Setup Apigeectl"

    #APIGEECTL_ROOT="$QUICKSTART_TOOLS"

    # Remove if it existed from an old install
    if [ -d "$APIGEECTL_ROOT" ]; then rm -rf "$APIGEECTL_ROOT"; fi
    mkdir -p "$APIGEECTL_ROOT"

    curl --fail -L  \
      -o "$APIGEECTL_ROOT/apigeectl.tar.gz" \
      "https://storage.googleapis.com/apigee-release/hybrid/apigee-hybrid-setup/$APIGEE_CTL_VERSION/$APIGEE_CTL"

    tar xvzf "$APIGEECTL_ROOT/apigeectl.tar.gz" -C "$APIGEECTL_ROOT"
    rm "$APIGEECTL_ROOT/apigeectl.tar.gz"

    mv "$APIGEECTL_ROOT"/apigeectl_*_64 "$APIGEECTL_HOME"

    echo "✅ Apigeectl set up in $APIGEECTL_HOME/apigeectl"
}

prepare_resources() {
    echo "🛠️ Configure Apigee hybrid"

    if [ -d "$HYBRID_HOME" ]; then rm -rf "$HYBRID_HOME"; fi
    mkdir -p "$HYBRID_HOME"

    mkdir -p "$HYBRID_HOME/overrides"
    mkdir  -p "$HYBRID_HOME/service-accounts"
    ln -s "$APIGEECTL_HOME/tools" "$HYBRID_HOME/tools"
    ln -s "$APIGEECTL_HOME/config" "$HYBRID_HOME/config"
    ln -s "$APIGEECTL_HOME/templates" "$HYBRID_HOME/templates"
    ln -s "$APIGEECTL_HOME/plugins" "$HYBRID_HOME/plugins"

    echo "✅ Hybrid Config Setup"
}

download_pylib() {
    echo "Installing all libraries if not available..."
    python3 -m pip install -r $1
}
########### Function Definitions ###########

install_packages "jq python3-pip python3-dev"
set_config_params $INPUTFILE
if [[ ! -z $ASM_VERSION ]] ; then
 install_asm
else
 echo "SKIPPING INSTALL ASM"
fi
download_apigee_ctl
prepare_resources
download_pylib "${SCRIPT_PATH}/helpers/requirements.txt"
export PATH=$PATH:$APIGEECTL_HOME
"$APIGEECTL_HOME"/apigeectl version