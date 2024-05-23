#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Get the parent directory of the script directory, which will be the network home
export UOCTFM_NETWORK_HOME=$(dirname "$SCRIPT_DIR")
cd $UOCTFM_NETWORK_HOME

# Import utils
source scripts/utils.sh
source scripts/envVar.sh

# Check if the script received at least one parameter
if [ $# -lt 1 ]; then
  warnln "The script must receive at least one parameter:"
  ecwarnlnho "1- CHANNEL_NAME"
  exit 1
fi

# Check if the script received more than two parameters
if [ $# -gt 2 ]; then
  warnln "The script must receive one or two parameters only."
  exit 1
fi

CHANNEL_NAME=$1
CC_NAME="ticketingSystemContract"
ORG_IDENTITY="client"

# Check if a second parameter was provided
if [ $# -eq 2 ]; then
  org_identity=$(echo "$2" | tr '[:upper:]' '[:lower:]')
  # Validate the second parameter
  if [ "$org_identity" = "developer" ] || [ "$org_identity" = "client" ] || [ "$org_identity" = "qa" ]; then
    ORG_IDENTITY="$org_identity"
  else
    warnln "Organization '$2' is an invalid identity. Please specify 'developer', 'client', or 'qa'."
    exit 1
  fi
fi

function prepareEnv() {

  export PATH=${UOCTFM_NETWORK_HOME}/../bin:${UOCTFM_NETWORK_HOME}:$PATH
  export FABRIC_CFG_PATH=${UOCTFM_NETWORK_HOME}/../config

  ORG1=""
  ORG2=""

  # Check the channel is "dev" or "qa" and set organizations accordingly
  if [[ $CHANNEL_NAME == *"dev"* ]]; then
    ORG1="client"
    ORG2="developer"
  elif [[ $CHANNEL_NAME == *"qa"* ]]; then
    ORG1="client"
    ORG2="qa"
  fi

  if [ -z "$ORG1" ] || [ -z "$ORG2" ]; then
    # Organizations cannot be determined for the channel
    errorln "For channel '$CHANNEL_NAME', Orgs cannot be determined!"
    errorln
    exit 1
  fi

  # Check endorsement policy
  if [ -n "$CC_END_POLICY" ]; then
    # not default [only one member], parsePeerConnectionParameters only with one peer
    parsePeerConnectionParameters $ORG_IDENTITY
  else
    # default [majority of members], parsePeerConnectionParameters with peer org1 and peer org2
    parsePeerConnectionParameters $ORG1 $ORG2
  fi

  # Check if peer tool exists
  checkTool peer

  # Export network configuration variables and certificates required to contact the peer identity of the org choosen
  setOrgIdentity $ORG_IDENTITY
}

########################################################################
# INVOKE CALL FUNCTIONS
########################################################################

function makeInvokeCC() {

  local CC_INVOKE_CTOR=$1
  local CC_INVOKE_CTOR_FORMATTED=$(formatCtorJson "$CC_INVOKE_CTOR" invoke)

  # Print and log the formatted chaincode constructor
  println "$CC_INVOKE_CTOR_FORMATTED" | tee -a "$CC_LOG_FILE"

  # Invoke the chaincode
  [ "$DEBUG_COMMANDS" = true ] && set -x
  invoke_output=$(peer chaincode invoke -o "$ORDERER_ADDRESS" --ordererTLSHostnameOverride orderer.uoctfm.com --tls --cafile "$ORDERER_CA" -C $CHANNEL_NAME -n $CC_NAME "${PEER_CONN_PARMS[@]}" -c "$CC_INVOKE_CTOR" 2>&1)
  res=$?
  { set +x; } 2>/dev/null

  println "$invoke_output" | tee -a $CC_LOG_FILE

  # Check if chaincode constructor uses function "OpenNewTicket"
  if [[ "$CC_INVOKE_CTOR" == *"OpenNewTicket"* ]]; then
    # Extract ticketId and export it
    export TICKET_ID=$(extractTicketId "$invoke_output")
  fi

  # Verify the result of the invoke operation
  verifyResult $res "Invoke execution by $PEERS failed!"
  successln "Invoke transaction successful by $PEERS on channel '$CHANNEL_NAME'"
}

function invokeInitLedger() {
  local ctor='{"Args":["InitLedger"]}'
  makeInvokeCC "$ctor"
}

function invokeOpenNewTicket() {
  local title="Implement Chaincode"
  local description="Develop and deploy a new chaincode for asset management on the Hyperledger Fabric network."
  local projectIdNum=99
  local creator="Friman Sanchez"
  local priority="HIGH"
  local initStoryPoints=5
  local ctor='{"Args":["OpenNewTicket","'$title'","'$description'","'$projectIdNum'","'$creator'","'$priority'","'$initStoryPoints'"]}'
  makeInvokeCC "$ctor"
}

function invokeUpdateTicketToInProgress() {
  local ticketId=$1
  if [[ -z "$ticketId" ]]; then
    errorln "Error in invokeUpdateTicketToInProgress: 'ticketId' parameter is required and cannot be empty."
    return 1
  fi
  local assigned="Alvaro Martin"
  local comment="Starting development on the assigned chaincode. Alvaro"
  local ctor='{"Args":["UpdateTicketToInProgress","'$ticketId'","'$assigned'","'$comment'"]}'
  makeInvokeCC "$ctor"
}

function invokeUpdateTicketToResolved() {
  local ticketId=$1
  if [[ -z "$ticketId" ]]; then
    errorln "Error in invokeUpdateTicketToResolved: 'ticketId' parameter is required and cannot be empty."
    return 1
  fi
  local relatedProductVersion="HLF 2.5.7"
  local realStoryPoints=8
  local comment="Finish development.Chaincode works fine! Finally it was more days than expected, so I update the story points to 8. Alvaro"
  local ctor='{"Args":["UpdateTicketToResolved","'$ticketId'","'$relatedProductVersion'","'$realStoryPoints'","'$comment'"]}'
  makeInvokeCC "$ctor"
}

function invokeUpdateTicketToClosed() {
  local ticketId=$1
  if [[ -z "$ticketId" ]]; then
    errorln "Error in invokeUpdateTicketToClosed: 'ticketId' parameter is required and cannot be empty."
    return 1
  fi
  local comment="OK, I close ticket. Friman"
  local ctor='{"Args":["UpdateTicketToClosed","'$ticketId'","'$comment'"]}'
  makeInvokeCC "$ctor"
}

function invokeDeleteTicket() {
  local ticketId=$1
  if [[ -z "$ticketId" ]]; then
    errorln "Error in invokeDeleteTicket: 'ticketId' parameter is required and cannot be empty."
    return 1
  fi
  local ctor='{"Args":["DeleteTicket","'$ticketId'"]}'
  makeInvokeCC "$ctor"
}

########################################################################
# QUERY CALL FUNCTIONS
########################################################################

function makeQueryCC() {

  local CC_QUERY_CTOR=$1
  local CC_QUERY_CTOR_FORMATTED=$(formatCtorJson "$CC_QUERY_CTOR" query)

  # Print and log the formatted chaincode constructor
  println "$CC_QUERY_CTOR_FORMATTED" | tee -a "$CC_LOG_FILE"

  # Query the chaincode
  [ "$DEBUG_COMMANDS" = true ] && set -x
  query_output=$(peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c "$CC_QUERY_CTOR" 2>&1)
  res=$?
  { set +x; } 2>/dev/null

  if [ $res -eq 0 ]; then
    println "$query_output" | tee >(jq -r '.' >>$CC_LOG_FILE) | jq -r '.'
  else
    println "$query_output" | tee -a $CC_LOG_FILE
  fi

  # Verify the result of the query operation
  PEER="'peer0.Org${ORG_IDENTITY^}'"
  verifyResult $res "Query execution from $PEER failed!"
  successln "Query successful from $PEER on channel '$CHANNEL_NAME'"
}

function queryReadTicket() {
  local ticketId=$1
  if [[ -z "$ticketId" ]]; then
    errorln "Error in queryReadTicket: 'ticketId' parameter is required and cannot be empty."
    return 1
  fi
  local ctor='{"Args":["ReadTicket","'$ticketId'"]}'
  makeQueryCC "$ctor"
}

function queryGetAllTickets() {
  local ctor='{"Args":["GetAllTickets"]}'
  makeQueryCC "$ctor"
}

function queryGetAllTicketsByProject() {
  local projectIdNum=$1
  if [[ -z "$projectIdNum" ]]; then
    errorln "Error in queryGetAllTicketsByProject: 'projectIdNum' parameter is required and cannot be empty."
    return 1
  fi
  local ctor='{"Args":["GetAllTicketsByProject","'${projectIdNum}'"]}'
  makeQueryCC "$ctor"
}

function queryGetAllTicketsByStatus() {
  local status=$1
  if [[ -z "$status" ]]; then
    errorln "Error in GetAllTicketsByStatus: 'status' parameter is required and cannot be empty."
    return 1
  fi
  local ctor='{"Args":["GetAllTicketsByStatus","'${status}'"]}'
  makeQueryCC "$ctor"
}

function queryGetTicketHistory() {
  local ticketId=$1
  if [[ -z "$ticketId" ]]; then
    errorln "Error in GetTicketHistory: 'ticketId' parameter is required and cannot be empty."
    return 1
  fi
  local ctor='{"Args":["GetTicketHistory","'${ticketId}'"]}'
  makeQueryCC "$ctor"
}

function test_Init_Retrieve() {
  invokeInitLedger
  sleep 2
  queryGetAllTickets
}

function test_Open_Update_History_Delete() {
  invokeOpenNewTicket
  sleep 2
  invokeUpdateTicketToInProgress "$TICKET_ID"
  sleep 5
  invokeUpdateTicketToResolved "$TICKET_ID"
  sleep 5
  invokeUpdateTicketToClosed "$TICKET_ID"
  sleep 5
  queryGetAllTicketsByStatus "CLOSED"
  queryReadTicket "$TICKET_ID"
  queryGetTicketHistory "$TICKET_ID"
  invokeDeleteTicket "$TICKET_ID"
  sleep 2
  queryGetAllTicketsByProject 99
}

function interact() {

  infoln "\n*** INTERACT WITH NETWORK ***\n"

  # Check for artifacts, fabric binaries and conf files
  checkOrgsAndOrdererArtifacts
  checkFabricBinaries
  checkFabricConf

  # Prepare the environment
  prepareEnv

  # init ledger with 6 tickets and retrieve them
  test_Init_Retrieve

  # open a new ticket and transition them through various states and finally delete it
  #test_Open_Update_History_Delete

}

interact
