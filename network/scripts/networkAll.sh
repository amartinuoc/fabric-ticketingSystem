#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

cd $SCRIPT_DIR

# execute all steps from delete and create network until deploy CC
function executeAllSteps() {
  # delete current network instance
  ./networkDelete.sh
  # create and start new network instance
  ./networkUp.sh
  # wait few seconds to services started
  sleep 2
  # create channels and join nodes to it
  ./networkCreateChannels.sh
  # deploy chaincode on channels
  ./networkDeployCC.sh
}

executeAllSteps
