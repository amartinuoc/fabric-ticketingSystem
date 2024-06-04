#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Get the parent directory of the script directory, which will be the network home
export NETWORK_HOME=$(dirname "$SCRIPT_DIR")
cd $NETWORK_HOME

# Import utils
source scripts/utils.sh
source scripts/envVar.sh

# Check if exactly 2 parameters were received
if [ $# -ne 0 ] && [ $# -ne 2 ]; then
  warnln "The script must receive either zero or two parameters:"
  warnln "1- CC_PROJECT"
  warnln "2- CC_VERSION"
  exit 1
fi

# Assign default values if no parameters were received
if [ $# -eq 0 ]; then
  CC_PROJECT="ticketingSystemContract"
  CC_VERSION="1.0"
else
  CC_PROJECT=$1
  CC_VERSION=$2
fi

CC_NAME=$CC_PROJECT
CC_LABEL="${CC_NAME}_${CC_VERSION}"
CC_PACKAGE="chaincodes/"${CC_NAME}_${CC_VERSION}".tar.gz"
CC_PROJECT_PATH="chaincodes/java/$CC_PROJECT"
CC_PROJECT_COMPILED_PATH="chaincodes/java/$CC_PROJECT/build/install/$CC_PROJECT"

function compileSourceCC() {

  infoln "\nCompiling Chaincode Java code"

  # Check for source code CC path and correct java version
  checkChaincodeSource $CC_PROJECT
  checkPrereqsJava11

  # Compile chaincode java code with openjdk 11
  println "Source code of chaincode can be found at '$CC_PROJECT_PATH/src'"
  cd "$CC_PROJECT_PATH"
  rm -rf bin/ build/
  [ "$DEBUG_COMMANDS" = true ] && set -x
  ./gradlew clean installDist --quiet
  res=$?
  { set +x; } 2>/dev/null
  cd $NETWORK_HOME

  verifyResult $res "Chaincode Java code compilation has failed!"
  successln "Chaincode Java code compilation finish!"

}

function packageCC() {

  infoln "\nPackaging the chaincode into compressed file '$CC_PACKAGE'"

  # Check for compiled CC path
  checkChaincodeIsCompiled $CC_PROJECT

  # Export network configuration variables and certificates required to contact the peer identity of the ORG choosen
  ORG=$1
  setOrgIdentity $ORG

  # Package the chaincode into a compressed file
  println "Compiled Source code of chaincode can be found at '$CC_PROJECT_COMPILED_PATH'"
  [ "$DEBUG_COMMANDS" = true ] && set -x
  peer lifecycle chaincode package $CC_PACKAGE --path $CC_PROJECT_COMPILED_PATH --lang java --label $CC_LABEL
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Chaincode packaging has failed!"

  # Find the CC package ID and export it
  export CC_PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid $CC_PACKAGE)
  println "CC_PACKAGE_ID is found and exported"

  successln "Chaincode is packaged!"

}

function installCCOnOnePeer() {

  # Export network configuration variables and certificates required to contact the peer identity of the chosen ORG
  ORG=$1
  infoln "\nInstalling chaincode '$CC_LABEL' on peer0 from org '$ORG'"
  setOrgIdentity $ORG

  # Install the compressed file (chaincode) on the peer of the chosen ORG
  [ "$DEBUG_COMMANDS" = true ] && set -x
  peer lifecycle chaincode install $CC_PACKAGE
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Chaincode installation on peer0 from org '$ORG' failed!"

  # Query the ID resulting from a combination of the chaincode name and the hash of the code content
  QUERYINSTALLED_JSON=$(peer lifecycle chaincode queryinstalled)
  println "${QUERYINSTALLED_JSON}"

  successln "Chaincode is installed on peer0 from org '$ORG' !"

}

function aprobeAndCommitCCOneChannel() {

  CHANNEL_NAME=$1
  ORG1=$2
  ORG2=$3

  infoln "\nTrying '$CC_LABEL' chaincode approvals on channel '$CHANNEL_NAME'"

  # Create endorsement policy parameter if policy is not default
  parseChaincodeEndPolicyParameter $ORG1 $ORG2

  # Export network configuration variables and certificates required to contact the peer identity of first org
  setOrgIdentity $ORG1

  # Approve the chaincode definition proposal installed on the peer of the first org.
  println "Approving chaincode on peer0 from org '$ORG1' ..."
  [ "$DEBUG_COMMANDS" = true ] && set -x
  peer lifecycle chaincode approveformyorg -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.uoctfm.com --channelID $CHANNEL_NAME $CC_END_POLICY_PARM --name $CC_NAME --version $CC_VERSION --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile "$ORDERER_CA" --waitForEvent
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Chaincode definition approved on peer 0 from org '$ORG1' on channel '$CHANNEL_NAME' failed!"

  # Export network configuration variables and certificates required to contact the peer identity of second org
  setOrgIdentity $ORG2

  # Approve the chaincode definition proposal installed on the peer of the second org.
  println "Approving chaincode on peer0 from org '$ORG2' ..."
  [ "$DEBUG_COMMANDS" = true ] && set -x
  peer lifecycle chaincode approveformyorg -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.uoctfm.com --channelID $CHANNEL_NAME $CC_END_POLICY_PARM --name $CC_NAME --version $CC_VERSION --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile "$ORDERER_CA" --waitForEvent
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Chaincode definition approved on peer 0 from org '$ORG2' on channel '$CHANNEL_NAME' failed!"

  successln "Chaincode definition approved on channel '$CHANNEL_NAME' !"

  infoln "\nTrying '$CC_LABEL' chaincode commit on channel '$CHANNEL_NAME'"

  # Check if the chaincode definition is ready to be committed to the channel.
  println "Checking chaincode definition is ready to be committed on channel '$CHANNEL_NAME' ..."
  [ "$DEBUG_COMMANDS" = true ] && set -x
  peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name $CC_NAME --version $CC_VERSION --sequence 1
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Check commit readiness is INVALID on peer0 from org '$ORG2' !"

  parsePeerConnectionParameters $ORG1 $ORG2

  # Export network configuration variables and certificates required to contact the peer identity of first org
  setOrgIdentity $ORG1

  # Commit the chaincode to the proposed channel
  [ "$DEBUG_COMMANDS" = true ] && set -x
  peer lifecycle chaincode commit -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.uoctfm.com --channelID $CHANNEL_NAME $CC_END_POLICY_PARM --name $CC_NAME --version $CC_VERSION --sequence 1 --tls --cafile "$ORDERER_CA" "${PEER_CONN_PARMS[@]}"
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Chaincode definition commit is FAILED on peer0 from org '$ORG1' !"

  # Query to check if the chaincode is registered on the channel
  infoln "Result of chaincode '$CC_LABEL' commit on channel '$CHANNEL_NAME': "
  QUERYCOMMITTED_JSON=$(peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name $CC_NAME --cafile "$ORDERER_CA" --output json)
  println "$QUERYCOMMITTED_JSON"

  successln "Chaincode definition committed on channel '$CHANNEL_NAME' !"

}

function deployChaincode() {

  infoln "\n$(generateTitleLogScript "DEPLOY CHAINCODE ON CHANNELS")"

  # Check for artifacts, fabric binaries and conf files
  checkOrgsAndOrdererArtifacts
  checkFabricBinaries
  checkFabricConf

  export PATH=${NETWORK_HOME}/../bin:${NETWORK_HOME}:$PATH
  export FABRIC_CFG_PATH=${NETWORK_HOME}/../config

  # Check if peer tool exists
  checkTool peer

  # compile chaincode source code
  compileSourceCC

  # Package CC in a file
  packageCC client

  # Install CC on each of the peers
  installCCOnOnePeer client
  installCCOnOnePeer developer
  installCCOnOnePeer qa

  # Approve and commit the CC on each of the peers of each channel
  aprobeAndCommitCCOneChannel channeldev client developer
  aprobeAndCommitCCOneChannel channelqa client qa

}

deployChaincode
