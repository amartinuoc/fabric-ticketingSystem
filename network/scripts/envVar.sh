#!/bin/bash

NETWORK_HOME=${NETWORK_HOME:-${PWD}}
source ${NETWORK_HOME}/scripts/utils.sh

# Verificar si el fichero config.properties existe
PROPERTIES_FILE="${NETWORK_HOME}/config.properties"
if [[ ! -f "$PROPERTIES_FILE" ]]; then
  fatalln "Properties file '$PROPERTIES_FILE' not found!"
  fatalln "Exiting"
  exit 1
fi

# Leer y exportar las variables del fichero config.properties
while IFS='=' read -r key value; do
  if [[ $key =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    eval "$key=\"$value\""
  fi
done <"$PROPERTIES_FILE"

# Function to check if WORK_ENVIRONMENT is valid
check_work_environment() {
  export WORK_ENVIRONMENT=$(echo "$WORK_ENVIRONMENT" | tr '[:upper:]' '[:lower:]')
  case "$WORK_ENVIRONMENT" in
  local | cloud)
    return 0
    ;;
  *)
    errorln "Properties file - Invalid WORK_ENVIRONMENT:$WORK_ENVIRONMENT. Allowed values: local, cloud."
    return 1
    ;;
  esac
}

# Function to check if ORG_NODE is valid
check_org_node() {
  export ORG_NODE=$(echo "$ORG_NODE" | tr '[:upper:]' '[:lower:]')
  case "$ORG_NODE" in
  orderer | developer | client | qa)
    return 0
    ;;
  *)
    errorln "Properties file - Invalid ORG_NODE:$ORG_NODE. Allowed values: orderer, developer, client, qa."
    return 1
    ;;
  esac
}

# Function to check if ANCHOR_PEERS is valid
check_anchor_peers() {
  export ANCHOR_PEERS=$(echo "$ANCHOR_PEERS" | tr '[:upper:]' '[:lower:]')
  case "$ANCHOR_PEERS" in
  true | false)
    return 0
    ;;
  *)
    errorln "Properties file - Invalid ANCHOR_PEERS:$ANCHOR_PEERS. Allowed values: true, false."
    return 1
    ;;
  esac
}

# Function to check if ID_CC_END_POLICY is valid and assign appropriate value to CC_END_POLICY
check_cc_end_policy() {
  case "$ID_CC_END_POLICY" in
  1)
    export CC_END_POLICY="OR('Org1.member','Org2.member')"
    return 0
    ;;
  2)
    export CC_END_POLICY=""
    return 0
    ;;
  *)
    errorln "Properties file - Invalid ID_CC_END_POLICY:$ID_CC_END_POLICY. Allowed values: 1,2."
    return 1
    ;;
  esac
}

# Function to check if ORDERING_SERVICE_TYPE is valid
check_ordering_service_type() {
  export ORDERING_SERVICE_TYPE=$(echo "$ORDERING_SERVICE_TYPE" | tr '[:upper:]' '[:lower:]')
  # Check the value of ORDERING_SERVICE_TYPE
  case "$ORDERING_SERVICE_TYPE" in
  # Allowed values: solo, kafka, raft
  solo | kafka | raft)
    return 0
    ;;
  *)
    # Print error message if the value is not valid
    errorln "Properties file - Invalid ORDERING_SERVICE_TYPE:$ORDERING_SERVICE_TYPE. Allowed values: solo, kafka, raft"
    return 1
    ;;
  esac
}

# Function to check if EXPLORER_TOOL is valid
check_explorer_tools() {
  export EXPLORER_TOOL=$(echo "$EXPLORER_TOOL" | tr '[:upper:]' '[:lower:]')
  case "$EXPLORER_TOOL" in
  true | false)
    return 0
    ;;
  *)
    errorln "Properties file - Invalid EXPLORER_TOOL:$EXPLORER_TOOL. Allowed values: true, false."
    return 1
    ;;
  esac
}

# Function to check if DEBUG_COMMANDS is valid
check_debug_commands() {
  export DEBUG_COMMANDS=$(echo "$DEBUG_COMMANDS" | tr '[:upper:]' '[:lower:]')
  case "$DEBUG_COMMANDS" in
  true | false)
    return 0
    ;;
  *)
    errorln "Properties file - Invalid DEBUG_COMMANDS:$DEBUG_COMMANDS. Allowed values: true, false."
    return 1
    ;;
  esac
}

# Function to check if node names are defined
check_names_nodes() {
  if [ -z "$ORDERER" ]; then
    errorln "Properties file - Missing ORDERER."
    return 1
  fi

  if [ -z "$PEER0_ORGDEV" ]; then
    errorln "Properties file - Missing PEER0_ORGDEV."
    return 1
  fi

  if [ -z "$PEER0_ORGCLIENT" ]; then
    errorln "Properties file - Missing PEER0_ORGCLIENT."
    return 1
  fi

  if [ -z "$PEER0_ORGQA" ]; then
    errorln "Properties file - Missing PEER0_ORGQA."
    return 1
  fi
  export ORDERER
  export PEER0_ORGDEV
  export PEER0_ORGCLIENT
  export PEER0_ORGQA
}

# Function to check if bucket name is defined
check_gcp_bucket_name() {
  if [ -z "$GCP_BUCKET_NAME" ]; then
    errorln "Properties file - Missing GCP_BUCKET_NAME."
    return 1
  fi
  export GCP_BUCKET_NAME
}

check_work_environment || exit 1
check_org_node || exit 1
check_anchor_peers || exit 1
check_cc_end_policy || exit 1
check_ordering_service_type || exit 1
check_explorer_tools || exit 1
check_debug_commands || exit 1
check_names_nodes || exit 1
check_gcp_bucket_name || exit 1

# Path to nodes docker-compose file according the work environment and node organization
if [[ "$WORK_ENVIRONMENT" == "local" ]]; then

  # Set the docker-compose file path for local environment
  export COMPOSE_FILE_PATH="docker/compose-net-all.yaml"

elif [[ "$WORK_ENVIRONMENT" == "cloud" ]]; then

  # Associative array to map ORG_NODE to corresponding docker-compose file paths
  declare -A compose_files=(
    [orderer]="docker/compose-net-orderer.yaml"
    [developer]="docker/compose-net-developer.yaml"
    [client]="docker/compose-net-client.yaml"
    [qa]="docker/compose-net-qa.yaml"
  )

  # Check if ORG_NODE is valid and set the compose file path
  if [[ -n "${compose_files[$ORG_NODE]}" ]]; then
    export COMPOSE_FILE_PATH="${compose_files[$ORG_NODE]}"
  else
    errorln "Invalid ORG_NODE value: $ORG_NODE"
    errorln "Allowed values: orderer, developer, client, qa. Exiting."
    exit 1
  fi

else

  errorln "Invalid WORK_ENVIRONMENT:$WORK_ENVIRONMENT"
  errorln "Allowed values: local, cloud. Exiting."
  exit 1

fi

# Set environment variables for the Explorer tool configuration
export EXPLORER_COMPOSE_FILE_PATH="explorer/compose-explorer.yaml"
export EXPLORER_CONFIG_FILE_PATH=${NETWORK_HOME}/explorer/config.json
export EXPLORER_PROFILE_DIR_PATH=${NETWORK_HOME}/explorer/connection-profile
export FABRIC_CRYPTO_PATH=${NETWORK_HOME}/organizations

# Set specific node names according the work environment
if [[ "$WORK_ENVIRONMENT" == "local" ]]; then
  # Set localhost for local environment
  ORDERER_NAME="localhost"
  PEER0_ORGDEV_NAME="localhost"
  PEER0_ORGCLIENT_NAME="localhost"
  PEER0_ORGQA_NAME="localhost"
elif [[ "$WORK_ENVIRONMENT" == "cloud" ]]; then
  # Set the specific names for cloud environment
  ORDERER_NAME=$ORDERER
  PEER0_ORGDEV_NAME=$PEER0_ORGDEV
  PEER0_ORGCLIENT_NAME=$PEER0_ORGCLIENT
  PEER0_ORGQA_NAME=$PEER0_ORGQA
else
  errorln "Invalid WORK_ENVIRONMENT:$WORK_ENVIRONMENT"
  errorln "Allowed values: local, cloud. Exiting."
  return 1
fi

# Set environment variables for generated certificates and network access
# for orderer
export ORDERER_CA=${NETWORK_HOME}/organizations/ordererOrganizations/uoctfm.com/orderers/orderer.uoctfm.com/msp/tlscacerts/tlsca.uoctfm.com-cert.pem
export ORDERER_ADMIN_TLS_SIGN_CERT=${NETWORK_HOME}/organizations/ordererOrganizations/uoctfm.com/orderers/orderer.uoctfm.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=${NETWORK_HOME}/organizations/ordererOrganizations/uoctfm.com/orderers/orderer.uoctfm.com/tls/server.key
export ORDERER_ADDRESS=${ORDERER_NAME}:7050
export ORDERER_ADDRESS_ADMIN=${ORDERER_NAME}:7053
export CORE_PEER_TLS_ENABLED=true

# Set environment variables for generated certificates and network access
# for each peer org
export PEER0_ORGDEV_CA=${NETWORK_HOME}/organizations/peerOrganizations/orgdev.uoctfm.com/peers/peer0.orgdev.uoctfm.com/tls/ca.crt
export PEER0_ORGDEV_ADDRESS=${PEER0_ORGDEV_NAME}:9051

export PEER0_ORGCLIENT_CA=${NETWORK_HOME}/organizations/peerOrganizations/orgclient.uoctfm.com/peers/peer0.orgclient.uoctfm.com/tls/ca.crt
export PEER0_ORGCLIENT_ADDRESS=${PEER0_ORGCLIENT_NAME}:7051

export PEER0_ORGQA_CA=${NETWORK_HOME}/organizations/peerOrganizations/orgqa.uoctfm.com/peers/peer0.orgqa.uoctfm.com/tls/ca.crt
export PEER0_ORGQA_ADDRESS=${PEER0_ORGQA_NAME}:11051
