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
DIR_CLOUD_STORAGE="cloud_storage"

function mountCloudStorage() {

  local mount_point="${NETWORK_HOME}/${DIR_CLOUD_STORAGE}"
  local bucket_name=$GCP_BUCKET_NAME

  # Check if the mount point is already mounted
  if ! mountpoint -q "$mount_point"; then
    # Create the mount point directory if it doesn't exist
    mkdir -p "$mount_point"
    rm -rf "$mount_point"/*
    # Attempt to mount the bucket
    gcsfuse "$bucket_name" "$mount_point"
    if [ $? -eq 0 ]; then
      println "Bucket is now mounted at '$mount_point'"
    else
      errorln "Error mounting the bucket. Trying to unmount and remount."
      # Attempt to unmount the mount point
      fusermount -u "$mount_point" 2>/dev/null
      sleep 2
      # Attempt to mount the bucket again
      gcsfuse "$bucket_name" "$mount_point"
      if [ $? -eq 0 ]; then
        println "Bucket mounted at '$mount_point' after retrying"
      else
        errorln "Error mounting the bucket after retrying"
        errorln "Exiting"
        errorln
        exit 1
      fi
    fi
  else
    println "Bucket already mounted at '$mount_point'"
  fi
}

function updateLocalHostsFile() {

  local hosts_file="/etc/hosts"
  local gcs_hosts_file="$DIR_CLOUD_STORAGE/hosts.txt"

  # Check if the GCS hosts file exists
  if [ ! -f "$gcs_hosts_file" ]; then
    errorln "Required file in CloudStorage not found: $gcs_hosts_file"
    errorln "Exiting"
    errorln
    exit 1
  fi

  # Check if the comment line exists
  if ! grep -q "# Ip-Host for blockchain network" "$hosts_file"; then
    echo "# Ip-Host for blockchain network" | sudo tee -a "$hosts_file"
  fi

  infoln "Trying read ip info for rest of nodes from bucket"

  # Read the GCS hosts file and update the local hosts file
  while IFS= read -r line; do
    local ip=$(echo "$line" | awk '{print $1}')
    local name=$(echo "$line" | awk '{print $2}')

    if grep -q "$name" "$hosts_file"; then
      sudo sed -i "s/^.*$name$/$ip $name/" "$hosts_file"
      println "Updated $name with IP $ip in '$hosts_file'"
    else
      echo "$ip $name" | sudo tee -a "$hosts_file"
      println "Added $name with IP $ip to '$hosts_file'"
    fi
  done <"$gcs_hosts_file"
}

# Function to check if the cloud storage directory exists and is mounted
function checkCloudStorageIsMount() {

  local mount_point="${NETWORK_HOME}/${DIR_CLOUD_STORAGE}"

  # Check if the cloud storage directory exists
  if [ ! -d "$mount_point" ]; then
    warnln "CloudStorage directory does not exist: '$mount_point'"
    return 1
  fi

  # Check if the cloud storage directory is mounted
  if ! mountpoint -q "$mount_point"; then
    warnln "CloudStorage is not mounted or not using gcsfuse: '$mount_point'"
    return 1
  fi

  return 0
}

# Function to check if the cloud storage directory contains the required directories and they are not empty
function checkCloudStorageHasContent() {
  local required_dirs=("ordererOrganizations" "peerOrganizations")

  for dir in "${required_dirs[@]}"; do
    local relative_path="$DIR_CLOUD_STORAGE/$dir"
    # Check if the required directory exists
    if [ ! -d "$relative_path" ]; then
      warnln "Required directory in CloudStorage not found: $dir"
      return 1
    # Check if the directory is not empty
    elif [ -z "$(ls -A "$relative_path")" ]; then
      warnln "Directory '$dir' in CloudStorage is empty"
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
    if checkCloudStorageIsMount; then
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
  println "Docker-compose used: '$COMPOSE_FILE_PATH'"
  docker-compose -f $COMPOSE_FILE_PATH up -d

  successln "Docker elements started successfully!"

}

function networkUp() {

  infoln "\n$(generateTitleLogScript "STARTING NETWORK")"

  # Check if WORK_ENVIRONMENT is 'cloud'
  if [[ "$WORK_ENVIRONMENT" == "cloud" ]]; then
    println
    mountCloudStorage
    # Check if cloud storage is mounted
    if checkCloudStorageIsMount; then
      # update file /etc/host with another IP nodes
      updateLocalHostsFile
      # Check if cloud storage contains required directories
      if checkCloudStorageHasContent; then
        # copy Organizations artifacts from cloud to local
        cp -r "$DIR_CLOUD_STORAGE/ordererOrganizations" "organizations/"
        cp -r "$DIR_CLOUD_STORAGE/peerOrganizations" "organizations/"
        println "Organizations artifacts: local <== cloudStorage"
      fi
    fi
  fi

  # generate orgs and orderer artifacts if they don't exist locally
  if ! existOrgsAndOrdererArtifacts; then
    # call the function to create the artifacts
    createOrgsAndOrdererArtifacts
  else
    infoln "\nOrganizations artifacts already exist locally. Not generating now!"
  fi

  createAndStartDockerElements

}

networkUp
