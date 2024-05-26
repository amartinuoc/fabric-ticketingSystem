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

export -f println
export -f errorln
export -f successln
export -f infoln
export -f warnln
export -f fatalln
export -f checkPrereqsDocker
export -f checkPrereqsJava11
export -f checkFabricBinaries
export -f checkFabricConf
export -f checkFabricConfTx
export -f checkOrgsAndOrdererArtifacts
export -f checkChaincodeSource
export -f checkChaincodeIsCompiled
export -f checkTool
export -f verifyResult
export -f formatCtorJson
export -f extractTicketId
export -f prettyOutputJson
