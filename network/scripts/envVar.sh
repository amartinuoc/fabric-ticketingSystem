#!/bin/bash

UOCTFM_NETWORK_HOME=${UOCTFM_NETWORK_HOME:-${PWD}}
. ${UOCTFM_NETWORK_HOME}/scripts/utils.sh

# Flag to enable or disable debugging commands
export DEBUG_COMMANDS=false
# Path to Chaincode calls log file
export CC_LOG_FILE=${UOCTFM_NETWORK_HOME}/logs/logCC.txt
# Path to docker-compose file
COMPOSE_FILE_PATH=docker/compose-net-all.yaml

# Chaincode endorsement policy using signature policy syntax.
export CC_END_POLICY="" #  The default policy requires an endorsement from Org1 and Org2
#export CC_END_POLICY="OR('Org1.member','Org2.member')" # requires an endorsement from Org1 or Org2"

# Set environment variables for generated certificates and network access by orderer
export ORDERER_CA=${UOCTFM_NETWORK_HOME}/organizations/ordererOrganizations/uoctfm.com/orderers/orderer.uoctfm.com/msp/tlscacerts/tlsca.uoctfm.com-cert.pem
export ORDERER_ADMIN_TLS_SIGN_CERT=${UOCTFM_NETWORK_HOME}/organizations/ordererOrganizations/uoctfm.com/orderers/orderer.uoctfm.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=${UOCTFM_NETWORK_HOME}/organizations/ordererOrganizations/uoctfm.com/orderers/orderer.uoctfm.com/tls/server.key
export ORDERER_ADDRESS=localhost:7050
export ORDERER_ADDRESS_ADMIN=localhost:7053
export CORE_PEER_TLS_ENABLED=true

# Set environment variables for generated certificates and network access by each peer org
export PEER0_ORGDEV_CA=${UOCTFM_NETWORK_HOME}/organizations/peerOrganizations/orgdev.uoctfm.com/peers/peer0.orgdev.uoctfm.com/tls/ca.crt
export PEER0_ORGDEV_ADDRESS=localhost:9051

export PEER0_ORGCLIENT_CA=${UOCTFM_NETWORK_HOME}/organizations/peerOrganizations/orgclient.uoctfm.com/peers/peer0.orgclient.uoctfm.com/tls/ca.crt
export PEER0_ORGCLIENT_ADDRESS=localhost:7051

export PEER0_ORGQA_CA=${UOCTFM_NETWORK_HOME}/organizations/peerOrganizations/orgqa.uoctfm.com/peers/peer0.orgqa.uoctfm.com/tls/ca.crt
export PEER0_ORGQA_ADDRESS=localhost:11051

# Set environment variables for the peer org specified
setOrgIdentity() {
  local USING_ORG=""
  if [ -z "$OVERRIDE_ORG" ]; then
    USING_ORG="$1"
  else
    USING_ORG="${OVERRIDE_ORG}"
  fi
  println "Using '${USING_ORG}' organization identity "
  if [ "$USING_ORG" == "developer" ]; then
    export CORE_PEER_LOCALMSPID="OrgDeveloperMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORGDEV_CA
    export CORE_PEER_MSPCONFIGPATH=${UOCTFM_NETWORK_HOME}/organizations/peerOrganizations/orgdev.uoctfm.com/users/Admin@orgdev.uoctfm.com/msp
    export CORE_PEER_ADDRESS=$PEER0_ORGDEV_ADDRESS
  elif [ "$USING_ORG" == "client" ]; then
    export CORE_PEER_LOCALMSPID="OrgClientMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORGCLIENT_CA
    export CORE_PEER_MSPCONFIGPATH=${UOCTFM_NETWORK_HOME}/organizations/peerOrganizations/orgclient.uoctfm.com/users/Admin@orgclient.uoctfm.com/msp
    export CORE_PEER_ADDRESS=$PEER0_ORGCLIENT_ADDRESS
  elif [ "$USING_ORG" == "qa" ]; then
    export CORE_PEER_LOCALMSPID="OrgQaMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORGQA_CA
    export CORE_PEER_MSPCONFIGPATH=${UOCTFM_NETWORK_HOME}/organizations/peerOrganizations/orgqa.uoctfm.com/users/Admin@orgqa.uoctfm.com/msp
    export CORE_PEER_ADDRESS=$PEER0_ORGQA_ADDRESS
  else
    errorln "ORG Unknown to use identity"
  fi

  if [ "$VERBOSE" = "true" ]; then
    env | grep CORE
  fi
}

# Helper function that sets the peer connection parameters for a chaincode operation
parsePeerConnectionParameters() {

  PEER_CONN_PARMS=()
  PEERS=""

  # Loop through all input arguments
  while [ "$#" -gt 0 ]; do
    setOrgIdentity "$1"

    PEER="'peer0.Org${1^}'"
    ## Set peer addresses
    if [ -z "$PEERS" ]; then
      PEERS="$PEER"
    else
      PEERS="$PEERS,$PEER"
    fi

    # Add peer address
    PEER_CONN_PARMS+=("--peerAddresses" "$CORE_PEER_ADDRESS")

    # Add TLS certificate path
    PEER_CONN_PARMS+=(--tlsRootCertFiles "$CORE_PEER_TLS_ROOTCERT_FILE")

    # Shift by one to get to the next organization identifier
    shift
  done

}

# Helper function that sets the endorsement policy parameters for a chaincode operation
parseChaincodeEndPolicyParameter() {

  CC_END_POLICY_PARM=$CC_END_POLICY
  local count=1

  # Loop through all input arguments
  while [ "$#" -gt 0 ]; do
    local orgIni="Org$count"
    local orgFin="Org${1^}MSP"

    # Add the formatted organization to the end policy parameters
    CC_END_POLICY_PARM="$(echo "$CC_END_POLICY_PARM" | sed "s/$orgIni/$orgFin/g")"

    # Increment the counter
    ((count++))

    # Shift by one to get to the next organization identifier
    shift
  done

  # Add --signature-policy if END_POLICY_PARM is not empty
  if [ -n "$CC_END_POLICY_PARM" ]; then
    warnln "Signature policy is '$CC_END_POLICY_PARM', which is no default"
    CC_END_POLICY_PARM="--signature-policy ${CC_END_POLICY_PARM}"
  fi

}
