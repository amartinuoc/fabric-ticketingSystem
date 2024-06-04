#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Get the parent directory of the script directory, which will be the network home
export NETWORK_HOME=$(dirname "$SCRIPT_DIR")
cd $NETWORK_HOME

# Import utils
source scripts/utils.sh
source scripts/envVar.sh

function getChannelProfile() {
  local channel=$1
  local ordering_service=$2

  # Ensure the ordering service is 'raft'
  if [[ $ordering_service != "raft" ]]; then
    errorln
    errorln "The '$ordering_service' consensus type is deprecated. Only 'raft' is recommended."
    errorln "You can check the release notes of the current version at:"
    errorln "https://github.com/hyperledger/fabric/releases/tag/v2.5.7"
    errorln
    errorln "Creation channel '$CHANNEL_NAME' not complete!"
    exit 1
  fi

  # Determine the profile based on the channel name
  if [[ $channel == *"dev"* ]]; then
    CHANNEL_PROFILE="ChannelDevUsingRaft"
  elif [[ $channel == *"qa"* ]]; then
    CHANNEL_PROFILE="ChannelQaUsingRaft"
  else
    errorln "Invalid CHANNEL_NAME: $channel. Profile cannot be determined"
    errorln
    errorln "Creation channel '$CHANNEL_NAME' not complete!"
    exit 1
  fi
}

function createGenesisBlockForOneChannel() {

  # Check if configtxgen tool exists
  checkTool configtxgen

  export FABRIC_CFG_PATH=${NETWORK_HOME}/configtx

  # Create the genesis block
  println "Generating genesis block for channel '$CHANNEL_NAME' ..."
  [ "$DEBUG_COMMANDS" = true ] && set -x
  configtxgen -profile $CHANNEL_PROFILE -outputBlock $GENESIS_BLOCK -channelID $CHANNEL_NAME
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Failed to generate genesis block!"

}

function joinOrdererAndPeersToOneChannel() {

  export FABRIC_CFG_PATH=${NETWORK_HOME}/../config

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

  # Add the peer0 from org1 to the channel
  println "Joining peer0 from org '$ORG1' to channel '$CHANNEL_NAME' ..."
  [ "$DEBUG_COMMANDS" = true ] && set -x
  peer channel join -b $GENESIS_BLOCK
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "peer0 from org '$ORG1' has failed to join channel '$CHANNEL_NAME' !"

  # Export network configuration variables and certificates required to contact with peer identity of second ORG
  setOrgIdentity $ORG2

  # Add the peer0 from org2 to the channel
  println "Joining peer0 from org '$ORG2' to channel '$CHANNEL_NAME' ..."
  [ "$DEBUG_COMMANDS" = true ] && set -x
  peer channel join -b $GENESIS_BLOCK
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "peer0 from org '$ORG2' has failed to join channel '$CHANNEL_NAME' !"

}

generateAnchorUpdateTx() {

  ORIGINAL=$1
  MODIFIED=$2
  OUTPUT=$3

  [ "$DEBUG_COMMANDS" = true ] && set -x
  configtxlator proto_encode --input "${ORIGINAL}" --type common.Config --output channel-artifacts/original_config.pb
  configtxlator proto_encode --input "${MODIFIED}" --type common.Config --output channel-artifacts/modified_config.pb
  configtxlator compute_update --channel_id "$CHANNEL_NAME" --original channel-artifacts/original_config.pb --updated channel-artifacts/modified_config.pb --output channel-artifacts/config_update.pb
  configtxlator proto_decode --input channel-artifacts/config_update.pb --type common.ConfigUpdate --output channel-artifacts/config_update.json
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat channel-artifacts/config_update.json)'}}}' | jq . >channel-artifacts/config_update_in_envelope.json
  configtxlator proto_encode --input channel-artifacts/config_update_in_envelope.json --type common.Envelope --output "${OUTPUT}"
  { set +x; } 2>/dev/null

  rm -f channel-artifacts/original_config.pb channel-artifacts/modified_config.pb channel-artifacts/config_update.pb channel-artifacts/config_update.json channel-artifacts/config_update_in_envelope.json

}

function setAnchorPeer() {

  checkTool jq

  ORG=$1
  CHANNEL_NAME=$2

  infoln "\nSetting Anchor peer for org '$CORE_PEER_LOCALMSPID' on channel '$CHANNEL_NAME'"

  setOrgIdentity $ORG

  case $ORG in
  developer)
    HOST=$PEER0_ORGDEV
    PORT=9051
    ;;
  client)
    HOST=$PEER0_ORGCLIENT
    PORT=7051
    ;;
  qa)
    HOST=$PEER0_ORGQA
    PORT=11051
    ;;
  *)
    errorln "Org '${ORG}' unknown. Anchor peer configuration not complete!"
    return 1
    ;;
  esac

  # Fetch the latest configuration block for the specified channel.
  config_orig_pb="channel-artifacts/${CHANNEL_NAME}_config.pb"
  println "Fetching channel config for channel '$CHANNEL_NAME'"
  [ "$DEBUG_COMMANDS" = true ] && set -x
  peer channel fetch config $config_orig_pb -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.uoctfm.com -c $CHANNEL_NAME --tls --cafile "$ORDERER_CA"
  { set +x; } 2>/dev/null

  # Decode the fetched configuration block to JSON and isolates the relevant configuration part
  config_orig_json="channel-artifacts/${CHANNEL_NAME}_config.json"
  config_orig_clean_json="channel-artifacts/${CHANNEL_NAME}_config_clean.json"
  println "Decoding config block to JSON and isolating config: ${config_orig_clean_json}"
  [ "$DEBUG_COMMANDS" = true ] && set -x
  configtxlator proto_decode --input $config_orig_pb --type common.Block --output $config_orig_json
  jq .data.data[0].payload.data.config $config_orig_json >"${config_orig_clean_json}"
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Failed to parse channel configuration. Anchor peer configuration not complete!"

  # Modify the original configuration JSON to include the anchor peer details.
  config_modified_json="channel-artifacts/${CORE_PEER_LOCALMSPID}_modified_config.json"
  println "Generating JSON with modifications: ${config_modified_json}"
  [ "$DEBUG_COMMANDS" = true ] && set -x
  jq '.channel_group.groups.Application.groups.'${CORE_PEER_LOCALMSPID}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'$HOST'","port": '$PORT'}]},"version": "0"}}' $config_orig_clean_json >$config_modified_json
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Channel configuration update for anchor peer failed. Anchor peer configuration not complete!"

  # Generate a transaction to update the anchor peer
  println "Generating anchor peer update transaction"
  anchor_update_tx=channel-artifacts/${CORE_PEER_LOCALMSPID}_anchors.tx
  generateAnchorUpdateTx $config_orig_clean_json $config_modified_json $anchor_update_tx

  # Update the anchor peer in the channel configuration
  println "Sending anchor peer update transaction to channel"
  [ "$DEBUG_COMMANDS" = true ] && set -x
  peer channel update -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.uoctfm.com -c $CHANNEL_NAME -f $anchor_update_tx --tls --cafile "$ORDERER_CA"
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Anchor peer update failed"

  successln "Anchor peer set for org '$CORE_PEER_LOCALMSPID' on channel '$CHANNEL_NAME'"

  rm -f $config_orig_pb $config_orig_json $config_orig_clean_json $config_modified_json $anchor_update_tx

}

function checkSettingAnchorPeers() {

  infoln "\nAnchor peers configured in the channel $CHANNEL_NAME:"

  # Fetch the latest configuration block of the channel from the orderer
  peer channel fetch config channel-artifacts/${CHANNEL_NAME}_last_config.pb -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.uoctfm.com -c $CHANNEL_NAME --tls --cafile "$ORDERER_CA"
  # Decode the protobuf configuration block file to JSON format
  configtxlator proto_decode --input channel-artifacts/${CHANNEL_NAME}_last_config.pb --type common.Block --output channel-artifacts/${CHANNEL_NAME}_last_config.json
  # Extract the config portion from the decoded JSON file
  jq .data.data[0].payload.data.config channel-artifacts/${CHANNEL_NAME}_last_config.json >channel-artifacts/${CHANNEL_NAME}_last_config_clean.json

  # Extract the anchor peers information from the cleaned JSON file
  anchor_peers_info=$(jq -r '.channel_group.groups.Application.groups | to_entries[] | select(.value.values.AnchorPeers != null) | .key, .value.values.AnchorPeers' channel-artifacts/${CHANNEL_NAME}_last_config_clean.json)

  if [ -z "$anchor_peers_info" ]; then
    warnln "No anchor peers configured"
  else
    println "$anchor_peers_info"
  fi
}

function createOneChannel() {

  export CHANNEL_NAME=$1
  export ORG1=$2
  export ORG2=$3
  export GENESIS_BLOCK="./channel-artifacts/$CHANNEL_NAME.block"

  infoln "\nCreating channel '$CHANNEL_NAME'"

  # Get the channel profile
  getChannelProfile $CHANNEL_NAME $ORDERING_SERVICE_TYPE

  # create Genesis Block and join Orderer And Peers to Channel
  createGenesisBlockForOneChannel
  joinOrdererAndPeersToOneChannel

  successln "Creation channel '$CHANNEL_NAME' finish!"

  sleep 1

  if [ "$ANCHOR_PEERS" = "true" ]; then
    # Set the anchor peer for each organization on the specified channel
    setAnchorPeer $ORG1 $CHANNEL_NAME
    setAnchorPeer $ORG2 $CHANNEL_NAME
    # Check and print the current anchor peers configuration
    checkSettingAnchorPeers
  fi

}

function createChannels() {

  infoln "\n$(generateTitleLogScript "CREATE CHANNELS")"

  # Check for artifacts, fabric binaries and conf files
  checkOrgsAndOrdererArtifacts
  checkFabricBinaries
  checkFabricConf
  checkFabricConfTx

  export PATH=${NETWORK_HOME}/../bin:${NETWORK_HOME}:$PATH

  # create directory for channel artifacts if not exists
  mkdir -p channel-artifacts

  # create channels with Orderer and org peers
  createOneChannel channeldev client developer
  createOneChannel channelqa client qa

  # Show the list of current channels associated with the Orderer
  infoln "\nCurrent available channels in network:"
  CHANNEL_LIST_JSON=$(osnadmin channel list -o $ORDERER_ADDRESS_ADMIN --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY")
  echo "$CHANNEL_LIST_JSON"

}

function startExplorerTool() {

  if [ "$EXPLORER_TOOL" = "true" ]; then

    infoln "\nStarting Explorer tool"

    # Check for neccesary files
    checkExplorerToolFiles
    # Check for docker prerequisites
    checkPrereqsDocker

    # Start docker services
    docker-compose -f $EXPLORER_COMPOSE_FILE_PATH up -d
    successln "Docker elements for Explorer tool started successfully!"

  fi

}

createChannels
startExplorerTool
