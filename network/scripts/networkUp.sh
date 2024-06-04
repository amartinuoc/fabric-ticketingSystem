#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Get the parent directory of the script directory, which will be the network home
export NETWORK_HOME=$(dirname "$SCRIPT_DIR")
cd $NETWORK_HOME

# Import utils
source scripts/utils.sh
source scripts/envVar.sh

# Directories for orderer and peer organizations
DIR_ORDERER="organizations/ordererOrganizations"
DIR_ORGS="organizations/peerOrganizations"

# Cloud storage directory
DIR_CLOUD_STORAGE="cloud-storage"

# Function to check if the cloud storage directory exists and is mounted
function checkCloudStorageMount() {

  local cloud_storage_path="${NETWORK_HOME}/${DIR_CLOUD_STORAGE}"

  # Check if the cloud storage directory exists
  if [ ! -d "$cloud_storage_path" ]; then
    warnln "CloudStorage directory does not exist: $cloud_storage_path"
    return 1
  fi

  # Check if the cloud storage directory is mounted using gcsfuse
  if ! mount | grep "on $cloud_storage_path type fuse.gcsfuse" >/dev/null; then
    warnln "CloudStorage is not mounted or not using gcsfuse: $cloud_storage_path"
    return 1
  fi

  return 0
}

# Function to check if the cloud storage directory contains the required directories and they are not empty
function checkCloudStorageContent() {
  local required_dirs=("ordererOrganizations" "peerOrganizations")

  for dir in "${required_dirs[@]}"; do
    local relative_path="$DIR_CLOUD_STORAGE/$dir"
    # Check if the required directory exists
    if [ ! -d "$relative_path" ]; then
      warnln "Required directory in CloudStorage not found: $dir"
      return 1
    # Check if the directory is not empty
    elif [ -z "$(ls -A "$relative_path")" ]; then
      warnln "Directory $dir in CloudStorage is empty"
      return 1
    fi
  done

  return 0
}

# Function to check if the orderer and peer organization artifacts exist and are not empty
function existOrgsAndOrdererArtifacts() {
  # Check if the orderer directory exists and is not empty
  if [[ -d "$DIR_ORDERER" && "$(ls -A "$DIR_ORDERER")" ]]; then
    # Check if the peer organizations directory exists and is not empty
    if [[ -d "$DIR_ORGS" && "$(ls -A "$DIR_ORGS")" ]]; then
      return 0
    fi
  fi
  return 1
}

function createArtifactsOneOrg() {

  ORG=$1
  println "Creating '$ORG' Artifacts (Identities) ..."
  [ "$DEBUG_COMMANDS" = true ] && set -x
  cryptogen generate --config=./organizations/cryptogen/crypto-config-org$ORG.yaml --output="organizations"
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate certificates!"
  fi

}

function createOrgsAndOrdererArtifacts() {

  # Check for fabric binaries and conf files
  checkFabricBinaries
  checkFabricConf

  infoln "\nCreating Organizations artifacts using cryptogen tool"
  export PATH=${NETWORK_HOME}/../bin:${NETWORK_HOME}:$PATH
  export FABRIC_CFG_PATH=${NETWORK_HOME}/../config

  # Check if cryptogen tool exists
  checkTool cryptogen

  # create directory for peers and orderer artifacts if not exist
  mkdir -p "$DIR_ORDERER" "$DIR_ORGS"

  # Create certificates and artifacts
  createArtifactsOneOrg Client
  createArtifactsOneOrg Dev
  createArtifactsOneOrg QA
  createArtifactsOneOrg Orderer

  successln "Organizations artifacts created successfully!"

  # Check if WORK_ENVIRONMENT is 'cloud'
  if [[ "$WORK_ENVIRONMENT" == "cloud" ]]; then
    # Check if cloud storage is mounted
    if checkCloudStorageMount; then
      # copy Organizations artifacts from local to cloud
      cp -r "organizations/ordererOrganizations" "$DIR_CLOUD_STORAGE"
      cp -r "organizations/peerOrganizations" "$DIR_CLOUD_STORAGE"
      println "Organizations artifacts: local ==> cloudStorage"
    fi
  fi

}

function createAndStartDockerElements() {

  # Check for docker prerequisites
  checkPrereqsDocker

  infoln "\nStarting docker elements: containers, volumes, and networks"

  # Start docker services
  docker-compose -f $COMPOSE_FILE_PATH up -d

  successln "Docker elements started successfully!"

}

function networkUp() {

  infoln "\n$(generateTitleLogScript "STARTING NETWORK")"

  # Check if WORK_ENVIRONMENT is 'cloud'
  if [[ "$WORK_ENVIRONMENT" == "cloud" ]]; then
    println
    # Check if cloud storage is mounted and contains required directories
    if checkCloudStorageMount && checkCloudStorageContent; then
      # copy Organizations artifacts from cloud to local
      cp -r "$DIR_CLOUD_STORAGE/ordererOrganizations" "organizations/"
      cp -r "$DIR_CLOUD_STORAGE/peerOrganizations" "organizations/"
      println "Organizations artifacts: cloudStorage ==> local"
    fi
  fi

  # generate orgs and orderer artifacts if they don't exist
  if ! existOrgsAndOrdererArtifacts; then
    # call the function to create the artifacts
    createOrgsAndOrdererArtifacts
  else
    infoln "\nOrganizations artifacts already exist locally. Not generating now!"
  fi

  createAndStartDockerElements

}

networkUp
