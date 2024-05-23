#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Get the parent directory of the script directory, which will be the network home
export UOCTFM_NETWORK_HOME=$(dirname "$SCRIPT_DIR")
cd $UOCTFM_NETWORK_HOME

# Import utils
source scripts/utils.sh
source scripts/envVar.sh

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

  infoln "\nCreating Orgs and Orderer artifacts using cryptogen tool"
  export PATH=${UOCTFM_NETWORK_HOME}/../bin:${UOCTFM_NETWORK_HOME}:$PATH
  export FABRIC_CFG_PATH=${UOCTFM_NETWORK_HOME}/../config

  # Check if cryptogen tool exists
  checkTool cryptogen

 # Create certificates and artifacts
  createArtifactsOneOrg Client
  createArtifactsOneOrg Dev
  createArtifactsOneOrg QA
  createArtifactsOneOrg Orderer

  successln "Orgs and Orderer Artifacts created successfully!"

}

function createAndStartContainers() {

  # Check for docker prerequisites
  checkPrereqsDocker

  infoln "\nStarting docker containers, volumes, and networks"

  # Start docker services
  docker-compose -f $COMPOSE_FILE_PATH up -d

  successln "Docker containers, volumes, and networks started successfully!"

}

function networkUp() {

  infoln "\n*** STARTING NETWORK ***"

  # generate orgs and orderer artifacts if they don't exist
  if [ ! -d "organizations/peerOrganizations" ] || [ ! -d "organizations/ordererOrganizations" ]; then
    # If at least one of the directories does not exist,
    # call the function to create the artifacts
    createOrgsAndOrdererArtifacts
  fi

  createAndStartContainers

}

networkUp
