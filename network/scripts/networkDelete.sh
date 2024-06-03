#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Get the parent directory of the script directory, which will be the network home
export NETWORK_HOME=$(dirname "$SCRIPT_DIR")
cd $NETWORK_HOME

# Import utils
source scripts/utils.sh
source scripts/envVar.sh

function networkDelete() {

  infoln "\n$(generateTitleLogScript "DELETING NETWORK")"

  # Remove previous certificates, chaincodes and channels configurations:
  println "\nDeleting Organizations artifacts, chaincode packages, channels configurations and logs locally"

  rm -rf organizations/peerOrganizations/*
  rm -rf organizations/ordererOrganizations/*
  rm -f chaincodes/*.tar.gz
  rm -rf channel-artifacts/*
  rm -rf logs
  rm -rf docker/.env

  # Check if WORK_ENVIRONMENT is 'cloud'
  if [[ "$WORK_ENVIRONMENT" == "cloud" ]]; then
    println "Deleting Organizations artifacts in cloudStorage dir"
    # Remove all inside the cloud storage directory
    rm -rf cloud-storage/*
  fi

  successln "Files deleted successfully!"

  # Check for docker prerequisites
  checkPrereqsDocker

  println "\nDeleting docker elements: containers, volumes, and networks"

  # Check if the container 'logspout' exists
  CONTAINER_LOGSPOUT=logspout
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_LOGSPOUT$"; then
    println "The container $CONTAINER_LOGSPOUT exists."
    println "Stopping $CONTAINER_LOGSPOUT ..."
    # Stop the container
    docker stop "$CONTAINER_LOGSPOUT"
    sleep 1
  fi

  # First, stop (only) docker services
  if [ "$EXPLORER_TOOL" = "true" ]; then
    docker-compose -f $EXPLORER_COMPOSE_FILE_PATH stop
  fi
  docker-compose -f $COMPOSE_FILE_PATH stop

  sleep 1

  # Then, down docker services and volumes
  if [ "$EXPLORER_TOOL" = "true" ]; then
    docker-compose -f $EXPLORER_COMPOSE_FILE_PATH down --volumes
  fi
  docker-compose -f $COMPOSE_FILE_PATH down --volumes

  successln "Docker elements deleted successfully!"

}

networkDelete
