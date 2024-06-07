#!/bin/bash

C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'

# println echos string
function println() {
  echo -e "$1"
}

# errorln echos i red color
function errorln() {
  println "${C_RED}${1}${C_RESET}"
}

# successln echos in green color
function successln() {
  println "${C_GREEN}${1}${C_RESET}"
}

# infoln echos in blue color
function infoln() {
  println "${C_BLUE}${1}${C_RESET}"
}

# warnln echos in yellow color
function warnln() {
  println "${C_YELLOW}${1}${C_RESET}"
}

# fatalln echos in red color and exits with fail status
function fatalln() {
  errorln "$1"
  exit 1
}

# Set environment variables for the peer org specified
setOrgIdentity() {
  local USING_ORG=""
  if [ -z "$OVERRIDE_ORG" ]; then
    USING_ORG="$1"
  else
    USING_ORG="${OVERRIDE_ORG}"
  fi
  println "Using '${USING_ORG}' organization identity"
  if [ "$USING_ORG" == "developer" ]; then
    export CORE_PEER_LOCALMSPID="OrgDeveloperMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORGDEV_CA
    export CORE_PEER_MSPCONFIGPATH=${NETWORK_HOME}/organizations/peerOrganizations/orgdev.uoctfm.com/users/Admin@orgdev.uoctfm.com/msp
    export CORE_PEER_ADDRESS=$PEER0_ORGDEV_ADDRESS
  elif [ "$USING_ORG" == "client" ]; then
    export CORE_PEER_LOCALMSPID="OrgClientMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORGCLIENT_CA
    export CORE_PEER_MSPCONFIGPATH=${NETWORK_HOME}/organizations/peerOrganizations/orgclient.uoctfm.com/users/Admin@orgclient.uoctfm.com/msp
    export CORE_PEER_ADDRESS=$PEER0_ORGCLIENT_ADDRESS
  elif [ "$USING_ORG" == "qa" ]; then
    export CORE_PEER_LOCALMSPID="OrgQaMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORGQA_CA
    export CORE_PEER_MSPCONFIGPATH=${NETWORK_HOME}/organizations/peerOrganizations/orgqa.uoctfm.com/users/Admin@orgqa.uoctfm.com/msp
    export CORE_PEER_ADDRESS=$PEER0_ORGQA_ADDRESS
  else
    errorln "ORG Unknown to use identity"
  fi

  if [ "$VERBOSE" = "true" ]; then
    env | grep CORE
  fi
}

function checkPrereqsDocker() {
  docker-compose --version >/dev/null 2>&1

  if [[ $? -ne 0 ]]; then
    errorln "docker-compose command not found..."
    errorln
    errorln "Follow the instructions to install docker-compose"
    errorln "https://docs.docker.com/compose/"
    exit 1
  fi

  if [[ ! -e "$COMPOSE_FILE_PATH" ]]; then
    errorln "Docker file '$COMPOSE_FILE_PATH' not found..."
    errorln
    exit 1
  fi
}

function checkPrereqsJava11() {
  local java_11_path=$(update-java-alternatives -l | awk '/java-1.11/ {print $3}')
  if [ -n "$java_11_path" ]; then
    export JAVA_HOME=$java_11_path
    println "JAVA_HOME has been set to: "$JAVA_HOME""
  else
    errorln "OpenJDK 11 is not installed. Please install OpenJDK 11."
    errorln
    errorln "Run the following command to install OpenJDK 11:"
    errorln "   sudo apt install openjdk-11-jdk"
    exit 1
  fi
}

function checkFabricBinaries() {
  local dir="../bin"
  if [[ ! -d "$dir" ]] || [[ ! "$(ls -A "$dir")" ]]; then
    errorln "Fabric command binaries not found in $dir !"
    errorln
    errorln "Follow the instructions in the Fabric docs to install the Fabric Binaries:"
    errorln "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
    exit 1
  fi
}

function checkFabricConf() {
  local dir="../config"
  if [[ ! -d "$dir" ]] || [[ ! "$(ls -A "$dir")" ]]; then
    errorln "Fabric configuration files not found in $dir !"
    errorln
    errorln "Follow the instructions in the Fabric docs to get the Fabric configuration files:"
    errorln "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
    exit 1
  fi
}

function checkFabricConfTx() {
  local dir="configtx"
  if [[ ! -d "$dir" ]] || [[ ! -f "$dir/configtx.yaml" ]]; then
    errorln "Fabric configuration channel file not found in $dir !"
    errorln
    errorln "Follow the instructions in the Fabric docs to get the Fabric configuration channel file:"
    errorln "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
    exit 1
  fi
}

function checkOrgsAndOrdererArtifacts() {
  local dirOrderer="organizations/ordererOrganizations"
  local dirOrgs="organizations/peerOrganizations"
  if [[ ! -d "$dirOrderer" ]] || [[ ! "$(ls -A "$dirOrderer")" ]]; then
    errorln "Certificates and configuration files not found in $dirOrderer !"
    errorln
    exit 1
  fi
  if [[ ! -d "$dirOrgs" ]] || [[ ! "$(ls -A "$dirOrgs")" ]]; then
    errorln "Certificates and configuration files not found in $dirOrgs !"
    errorln
    exit 1
  fi
}

checkExplorerToolFiles() {
  local explorer_dir="explorer"
  local compose_file="$explorer_dir/compose-explorer.yaml"
  local config_file="$explorer_dir/config.json"
  local connection_dir="$explorer_dir/connection-profile"
  local info_error="Follow the instructions in the Fabric repo to install Explorer:
  https://github.com/hyperledger-labs/blockchain-explorer"

  if [[ ! -d "$explorer_dir" ]]; then
    errorln "The directory '$explorer_dir' does not exist."
    errorln "$info_error"
    exit 1
  fi

  if [[ ! -f "$compose_file" ]]; then
    errorln "The file '$compose_file' does not exist."
    errorln "$info_error"
    exit 1
  fi

  if [[ ! -f "$config_file" ]]; then
    errorln "The file '$config_file' does not exist."
    errorln "$info_error"
    exit 1
  fi

  if [[ ! -d "$connection_dir" ]]; then
    errorln "The directory '$connection_dir' does not exist."
    errorln "$info_error"
    exit 1
  fi

}

function checkChaincodeSource() {
  local nameProject=$1
  local dirSource="chaincodes/java/$nameProject"
  if [[ ! -d "$dirSource" ]] || [[ ! "$(ls -A "$dirSource")" ]]; then
    errorln "Chaincode '$nameProject': source code not found in "$dirSource" !"
    errorln
    exit 1
  fi
}

function checkChaincodeIsCompiled() {
  local nameProject=$1
  local dirCompilation="chaincodes/java/$nameProject/build/install/$nameProject"
  if [[ ! -d "$dirCompilation" ]] || [[ ! "$(ls -A "$dirCompilation")" ]]; then
    errorln "Chaincode '$nameProject': compilation not found in "$dirCompilation" !"
    errorln
    exit 1
  fi
}

function checkTool() {
  local command_name=$1
  which "$command_name" >/dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    errorln "'$command_name' tool not found. Exiting ..."
    exit 1
  fi
}

function verifyResult() {
  if [ $1 -ne 0 ]; then
    fatalln "$2"
  fi
}

# Function to process the Json constructor in calls to CC
function formatCtorJson() {

  local ctorJson="$1"
  local org_identity="$2"
  local type="$3"
  local current_datetime=$(date +"%Y-%m-%d %H:%M:%S.%3N")
  echo "\n- Timestamp: $current_datetime"

  # Check if jq is installed
  if command -v jq &>/dev/null; then
    # installed, apply jq

    # Extraer el primer elemento del JSON
    local function=$(echo "$ctor" | jq -r '.Args[0]')
    # Extraer el resto de los elementos como un array
    local parameters=$(echo "$ctor" | jq -r '.Args[1:] | @tsv')

    echo "- Function: $function [chaincode $type by org '$org_identity']"

    # Dividir los parámetros en un array
    IFS=$'\t' read -r -a params_array <<<"$parameters"

    # Iterar sobre los parámetros
    for i in "${!params_array[@]}"; do
      echo "- Parameter_$((i + 1)): ${params_array[i]}"
    done

  else
    # not installed
    echo "Ctor: $ctorJson"
  fi

}

# Function to extract ticketId value from a json response with 'chaincode invoke'
function extractTicketId() {

  local response="$1"

  # Extract the JSON payload from the response
  local json_payload
  json_payload=$(echo "$response" | grep -oP 'payload:.*?({.*})' | sed 's/payload:\/"//')

  # Decode the JSON payload (replace escaped quotes with actual quotes) and extract the ticketId
  local ticket_id
  ticket_id=$(echo "$json_payload" | sed 's/\\"/"/g' | grep -oP '(?<="ticketId":")[^"]+')

  echo "$ticket_id"

}

# Function to process the Json output of a command (with or without jq)
function prettyOutputJson() {

  local outputIni="$1"
  local outputFin

  # Check if jq is installed
  if command -v jq &>/dev/null; then
    # installed, apply jq to the output
    outputFin=$(echo "$outputIni" | jq -r)
  else
    # not installed, store the raw output
    outputFin="$outputIni"
  fi

  echo "$outputFin"

}

# Helper function that sets the peer connection parameters for a chaincode operation
parsePeerConnectionParameters() {

  PEER_CONN_PARMS=()
  PEERS=""

  # Loop through all input arguments
  while [ "$#" -gt 0 ]; do
    setOrgIdentity "$1"

    PEER="'peer0.Org${1^}'"
    ## Set peer addresses
    if [ -z "$PEERS" ]; then
      PEERS="$PEER"
    else
      PEERS="$PEERS,$PEER"
    fi

    # Add peer address
    PEER_CONN_PARMS+=("--peerAddresses" "$CORE_PEER_ADDRESS")

    # Add TLS certificate path
    PEER_CONN_PARMS+=(--tlsRootCertFiles "$CORE_PEER_TLS_ROOTCERT_FILE")

    # Shift by one to get to the next organization identifier
    shift
  done

}

# Helper function that sets the endorsement policy parameters for a chaincode operation
parseChaincodeEndPolicyParameter() {

  CC_END_POLICY_PARM=$CC_END_POLICY
  local count=1

  # Loop through all input arguments
  while [ "$#" -gt 0 ]; do
    local orgIni="Org$count"
    local orgFin="Org${1^}MSP"

    # Add the formatted organization to the end policy parameters
    CC_END_POLICY_PARM="$(echo "$CC_END_POLICY_PARM" | sed "s/$orgIni/$orgFin/g")"

    # Increment the counter
    ((count++))

    # Shift by one to get to the next organization identifier
    shift
  done

  # Add --signature-policy if END_POLICY_PARM is not empty
  if [ -n "$CC_END_POLICY_PARM" ]; then
    warnln "Signature policy is '$CC_END_POLICY_PARM', which is no default"
    CC_END_POLICY_PARM="--signature-policy ${CC_END_POLICY_PARM}"
  fi

}

# Function to generate a title log for script
generateTitleLogScript() {

  local special_chars="****************"

  local environment="[environment: $WORK_ENVIRONMENT"

  # If the environment is "cloud", include the organization node
  if [[ "$WORK_ENVIRONMENT" == "cloud" ]]; then
    local org="node: $ORG_NODE"
  fi

  # Concatenate the text of the environment and the organization node (if available)
  local result="$environment"
  if [[ ! -z "$org" ]]; then
    result+=", $org"
  fi

  # Add closing brackets
  result+="]"

  echo "$special_chars $1 $result $special_chars"
}

export -f println
export -f errorln
export -f successln
export -f infoln
export -f warnln
export -f fatalln
export -f setOrgIdentity
export -f checkPrereqsDocker
export -f checkPrereqsJava11
export -f checkFabricBinaries
export -f checkFabricConf
export -f checkFabricConfTx
export -f checkOrgsAndOrdererArtifacts
export -f checkExplorerToolFiles
export -f checkChaincodeSource
export -f checkChaincodeIsCompiled
export -f checkTool
export -f verifyResult
export -f formatCtorJson
export -f extractTicketId
export -f prettyOutputJson
export -f parsePeerConnectionParameters
export -f parseChaincodeEndPolicyParameter
export -f generateTitleLogScript
