#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Get the parent directory of the script directory, which will be the network home
export UOCTFM_NETWORK_HOME=$(dirname "$SCRIPT_DIR")
cd $UOCTFM_NETWORK_HOME

# Import utils
source scripts/utils.sh
source scripts/envVar.sh

function networkDelete() {

  infoln "\n*** DELETING NETWORK ***\n"

  # Remove previous certificates and channel configurations:
  println "Deleting certificates, channel configurations, genesis blocks, chaincode packages, logs ..."
  rm -rf organizations/peerOrganizations
  rm -rf organizations/ordererOrganizations
  mkdir -p channel-artifacts
  rm -rf channel-artifacts/*
  rm -f chaincodes/*.tar.gz
  mkdir -p logs
  rm -rf logs/*

  successln "Files deleted successful!"

  # Check for docker prerequisites
  checkPrereqsDocker

  println "Deleting docker containers, volumes, and networks ..."

  # Check if the container 'logspout' exists
  CONTAINER_LOGSPOUT=logspout
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_LOGSPOUT$"; then
    println "The container $CONTAINER_LOGSPOUT exists."
    println "Stopping $CONTAINER_LOGSPOUT ..."
    # Stop the container
    docker stop "$CONTAINER_LOGSPOUT"
    sleep 1
  fi

  # Stop and down docker services
  docker-compose -f $COMPOSE_FILE_PATH down --volumes

  successln "Docker containers, volumes, and networks deleted successfully!"

}

networkDelete
