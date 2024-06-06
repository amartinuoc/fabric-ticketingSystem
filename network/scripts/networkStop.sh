#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Get the parent directory of the script directory, which will be the network home
export NETWORK_HOME=$(dirname "$SCRIPT_DIR")
cd $NETWORK_HOME

# Import utils
source scripts/utils.sh
source scripts/envVar.sh

function networkStop() {

  infoln "\n$(generateTitleLogScript "STOPPING NETWORK")"

  # Check for docker prerequisites
  checkPrereqsDocker

  println "\nStopping docker elements: containers, volumes, and networks"

  # Check if the container 'logspout' exists
  CONTAINER_LOGSPOUT=logspout
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_LOGSPOUT$"; then
    println "The container $CONTAINER_LOGSPOUT exists."
    println "Stopping $CONTAINER_LOGSPOUT ..."
    # Stop the container
    docker stop "$CONTAINER_LOGSPOUT"
    sleep 1
  fi

  # Stop docker services
  if [ "$EXPLORER_TOOL" = "true" ]; then
    println "Docker-compose used: '$EXPLORER_COMPOSE_FILE_PATH'"
    docker-compose -f $EXPLORER_COMPOSE_FILE_PATH stop
  fi
  println "Docker-compose used: '$COMPOSE_FILE_PATH'"
  docker-compose -f $COMPOSE_FILE_PATH stop

  successln "Docker elements stopped successfully!"

}

networkStop
