#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

cd $SCRIPT_DIR

function finishIfError() {
  echo
  echo "Error executing script '$1.sh'"
  exit 1
}

# execute all steps from delete and create network until deploy CC
function executeAllSteps() {
  # delete current network instance
  ./networkDelete.sh || finishIfError "networkDelete"
  # create and start new network instance
  ./networkUp.sh || finishIfError "networkUp"
  # wait few seconds to services started
  sleep 2
  # create channels and join nodes to it
  ./networkCreateChannels.sh || finishIfError "networkCreateChannels"
  # deploy chaincode on channels
  ./networkDeployCC.sh || finishIfError "networkDeployCC"
}

executeAllSteps
