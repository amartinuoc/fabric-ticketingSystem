#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Get the parent directory of the script directory, which will be the network home
export UOCTFM_NETWORK_HOME=$(dirname "$SCRIPT_DIR")
cd $UOCTFM_NETWORK_HOME

# Import utils
source scripts/utils.sh
source scripts/envVar.sh

function createGenesisBlockForOneChannel() {

  # Check if configtxgen tool exists
  checkTool configtxgen

  export FABRIC_CFG_PATH=${UOCTFM_NETWORK_HOME}/configtx

  # Create channel configuration and the genesis block
  println "Generating channel configuration and genesis block for channel '$CHANNEL_NAME' ..."
  [ "$DEBUG_COMMANDS" = true ] && set -x
  configtxgen -profile $CHANNEL_PROFILE -outputBlock $GENESIS_BLOCK -channelID $CHANNEL_NAME
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Failed to generate channel configuration transaction!"

}

function joinOrdererAndPeersToOneChannel() {

  export FABRIC_CFG_PATH=${UOCTFM_NETWORK_HOME}/../config

  # Check if osnadmin tool exists
  checkTool osnadmin

  # Send channel configuration to the Orderer to join it
  println "Joining Orderer to channel '$CHANNEL_NAME' with profile '$CHANNEL_PROFILE' ..."
  [ "$DEBUG_COMMANDS" = true ] && set -x
  osnadmin channel join --channelID $CHANNEL_NAME --config-block $GENESIS_BLOCK -o $ORDERER_ADDRESS_ADMIN --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Orderer has failed to join channel '$CHANNEL_NAME' !"

  # Check if peer tool exists
  checkTool peer

  # Export network configuration variables and certificates required to contact with peer identity of first ORG
  setOrgIdentity $ORG1

  # Add the peer 0 from org1 to the channel
  println "Joining peer 0 from org '$ORG1' to channel '$CHANNEL_NAME' ..."
  [ "$DEBUG_COMMANDS" = true ] && set -x
  peer channel join -b $GENESIS_BLOCK
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "peer 0 from org '$ORG1' has failed to join channel '$CHANNEL_NAME' !"

  # Export network configuration variables and certificates required to contact with peer identity of second ORG
  setOrgIdentity $ORG2

  # Add the peer 0 from org2 to the channel
  println "Joining peer 0 from org '$ORG2' to channel '$CHANNEL_NAME' ..."
  [ "$DEBUG_COMMANDS" = true ] && set -x
  peer channel join -b $GENESIS_BLOCK
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "peer 0 from org '$ORG2' has failed to join channel '$CHANNEL_NAME' !"

}

function createOneChannel() {

  export CHANNEL_NAME=$1
  export ORG1=$2
  export ORG2=$3
  export GENESIS_BLOCK="./channel-artifacts/$CHANNEL_NAME.block"

  infoln "\nCreating channel '$CHANNEL_NAME'"

  CHANNEL_PROFILE=""

  # get profile from channel name
  if [[ $CHANNEL_NAME == *"dev"* ]]; then
    export CHANNEL_PROFILE="ChannelDevUsingRaft"
  elif [[ $CHANNEL_NAME == *"qa"* ]]; then
    export CHANNEL_PROFILE="ChannelQaUsingRaft"
  fi

  # error when getting profile
  if [[ -z "$CHANNEL_PROFILE" ]]; then
    errorln "Profile with 'configtxgen' cannot be determined for '$CHANNEL_NAME' channel"
    errorln
    errorln "Creation channel '$CHANNEL_NAME' not complete!"
    exit 1
  fi

  # create Genesis Block and join Orderer And Peers to Channel
  createGenesisBlockForOneChannel
  joinOrdererAndPeersToOneChannel

  successln "Creation channel '$CHANNEL_NAME' finish!"

}

function createChannels() {

  infoln "\n*** CREATE CHANNELS ***"

  # Check for artifacts, fabric binaries and conf files
  checkOrgsAndOrdererArtifacts
  checkFabricBinaries
  checkFabricConf
  checkFabricConfTx

  export PATH=${UOCTFM_NETWORK_HOME}/../bin:${UOCTFM_NETWORK_HOME}:$PATH

  # create channels with Orderer and org peers
  createOneChannel channeldev client developer
  createOneChannel channelqa client qa

  # Show the list of current channels associated with the Orderer
  infoln "\nCurrent available channels in network:"
  CHANNEL_LIST_JSON=$(osnadmin channel list -o $ORDERER_ADDRESS_ADMIN --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY")
  echo "$CHANNEL_LIST_JSON"

}

createChannels
