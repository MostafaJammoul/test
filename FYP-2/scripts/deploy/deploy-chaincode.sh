#!/bin/bash
#
# Deploy Chaincode to Specified Chain
# Usage: ./deploy-chaincode.sh [hot|cold]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Chaincode configuration
CC_NAME="custody"
CC_VERSION="1.0"
CC_SEQUENCE="1"
CC_SRC_PATH="${PROJECT_ROOT}/chaincode/public"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying Chaincode${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check arguments
if [ "$#" -ne 1 ]; then
    print_error "Usage: $0 [hot|cold]"
    exit 1
fi

CHAIN_TYPE=$1

# Set chain-specific variables
if [ "$CHAIN_TYPE" = "hot" ]; then
    CHAIN_DIR="${PROJECT_ROOT}/fabric-network/hot-chain"
    CHANNEL_NAME="evidence-hot"
    ORDERER_ADDRESS="orderer0.orderer.hot.dfir.local:7050"
    LAB_PEER0="peer0.lab.hot.dfir.local"
    LAB_PEER1="peer1.lab.hot.dfir.local"
    COURT_PEER0="peer0.court.hot.dfir.local"
    COURT_PEER1="peer1.court.hot.dfir.local"
elif [ "$CHAIN_TYPE" = "cold" ]; then
    CHAIN_DIR="${PROJECT_ROOT}/fabric-network/cold-chain"
    CHANNEL_NAME="evidence-cold"
    ORDERER_ADDRESS="orderer0.orderer.cold.dfir.local:8050"
    LAB_PEER0="peer0.lab.cold.dfir.local"
    LAB_PEER1="peer1.lab.cold.dfir.local"
    COURT_PEER0="peer0.court.cold.dfir.local"
    COURT_PEER1="peer1.court.cold.dfir.local"
else
    print_error "Invalid chain type. Use 'hot' or 'cold'"
    exit 1
fi

ORDERER_CA="${CHAIN_DIR}/crypto-config/ordererOrganizations/orderer.${CHAIN_TYPE}.dfir.local/orderers/orderer0.orderer.${CHAIN_TYPE}.dfir.local/msp/tlscacerts/tlsca.orderer.${CHAIN_TYPE}.dfir.local-cert.pem"

print_status "Deploying to ${CHAIN_TYPE} chain"
print_status "Channel: ${CHANNEL_NAME}"
echo ""

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."

    # Check if chaincode source exists
    if [ ! -d "$CC_SRC_PATH" ]; then
        print_error "Chaincode source not found at $CC_SRC_PATH"
        exit 1
    fi

    # Check if network is running
    if ! docker ps | grep -q "$LAB_PEER0"; then
        print_error "${CHAIN_TYPE} chain network is not running"
        exit 1
    fi

    # Check if channel exists
    if ! docker exec $LAB_PEER0 peer channel list | grep -q "$CHANNEL_NAME"; then
        print_error "Channel $CHANNEL_NAME not found. Please create channel first."
        exit 1
    fi

    print_status "Prerequisites check passed"
    echo ""
}

# Package chaincode
package_chaincode() {
    print_step "Packaging chaincode..."

    cd "$CC_SRC_PATH"

    # Initialize go module if not exists
    if [ ! -f "go.sum" ]; then
        print_status "Initializing Go module..."
        docker run --rm -v "$CC_SRC_PATH:/chaincode" -w /chaincode golang:1.21 \
            sh -c "go mod tidy && go mod vendor"
    fi

    # Create package directory
    mkdir -p "${PROJECT_ROOT}/chaincode-packages"
    PACKAGE_FILE="${PROJECT_ROOT}/chaincode-packages/${CC_NAME}.tar.gz"

    # Package chaincode
    docker exec $LAB_PEER0 peer lifecycle chaincode package \
        /tmp/${CC_NAME}.tar.gz \
        --path /opt/gopath/src/github.com/chaincode/public \
        --lang golang \
        --label ${CC_NAME}_${CC_VERSION}

    # Copy package out of container
    docker cp $LAB_PEER0:/tmp/${CC_NAME}.tar.gz $PACKAGE_FILE

    if [ -f "$PACKAGE_FILE" ]; then
        print_status "Chaincode packaged: $PACKAGE_FILE"
    else
        print_error "Failed to package chaincode"
        exit 1
    fi

    echo ""
}

# Install chaincode on ForensicLabMSP peers
install_lab_peers() {
    print_step "Installing chaincode on ForensicLabMSP peers..."

    PACKAGE_FILE="${PROJECT_ROOT}/chaincode-packages/${CC_NAME}.tar.gz"

    # Install on peer0.lab
    print_status "Installing on $LAB_PEER0..."
    docker cp $PACKAGE_FILE $LAB_PEER0:/tmp/${CC_NAME}.tar.gz
    docker exec $LAB_PEER0 peer lifecycle chaincode install /tmp/${CC_NAME}.tar.gz

    # Install on peer1.lab
    print_status "Installing on $LAB_PEER1..."
    docker cp $PACKAGE_FILE $LAB_PEER1:/tmp/${CC_NAME}.tar.gz
    docker exec $LAB_PEER1 peer lifecycle chaincode install /tmp/${CC_NAME}.tar.gz

    print_status "Chaincode installed on ForensicLabMSP peers"
    echo ""
}

# Install chaincode on CourtMSP peers
install_court_peers() {
    print_step "Installing chaincode on CourtMSP peers..."

    PACKAGE_FILE="${PROJECT_ROOT}/chaincode-packages/${CC_NAME}.tar.gz"

    # Install on peer0.court
    print_status "Installing on $COURT_PEER0..."
    docker cp $PACKAGE_FILE $COURT_PEER0:/tmp/${CC_NAME}.tar.gz
    docker exec $COURT_PEER0 peer lifecycle chaincode install /tmp/${CC_NAME}.tar.gz

    # Install on peer1.court
    print_status "Installing on $COURT_PEER1..."
    docker cp $PACKAGE_FILE $COURT_PEER1:/tmp/${CC_NAME}.tar.gz
    docker exec $COURT_PEER1 peer lifecycle chaincode install /tmp/${CC_NAME}.tar.gz

    print_status "Chaincode installed on CourtMSP peers"
    echo ""
}

# Get package ID
get_package_id() {
    print_step "Querying installed chaincode..."

    PACKAGE_ID=$(docker exec $LAB_PEER0 peer lifecycle chaincode queryinstalled | \
        grep "${CC_NAME}_${CC_VERSION}" | \
        awk '{print $3}' | \
        sed 's/,$//')

    if [ -z "$PACKAGE_ID" ]; then
        print_error "Failed to get package ID"
        exit 1
    fi

    print_status "Package ID: $PACKAGE_ID"
    echo ""
}

# Approve chaincode for ForensicLabMSP
approve_lab() {
    print_step "Approving chaincode for ForensicLabMSP..."

    docker exec $LAB_PEER0 peer lifecycle chaincode approveformyorg \
        -o $ORDERER_ADDRESS \
        --channelID $CHANNEL_NAME \
        --name $CC_NAME \
        --version $CC_VERSION \
        --package-id $PACKAGE_ID \
        --sequence $CC_SEQUENCE \
        --tls \
        --cafile $ORDERER_CA \
        --waitForEvent

    print_status "Chaincode approved for ForensicLabMSP"
    echo ""
}

# Approve chaincode for CourtMSP
# Note: For hot chain, CourtMSP approval is optional since they are read-only participants
approve_court() {
    if [ "$CHAIN_TYPE" = "hot" ]; then
        print_step "Approving chaincode for CourtMSP (optional for hot chain - read-only participant)..."
    else
        print_step "Approving chaincode for CourtMSP..."
    fi

    docker exec $COURT_PEER0 peer lifecycle chaincode approveformyorg \
        -o $ORDERER_ADDRESS \
        --channelID $CHANNEL_NAME \
        --name $CC_NAME \
        --version $CC_VERSION \
        --package-id $PACKAGE_ID \
        --sequence $CC_SEQUENCE \
        --tls \
        --cafile $ORDERER_CA \
        --waitForEvent

    print_status "Chaincode approved for CourtMSP"
    echo ""
}

# Check commit readiness
check_commit_readiness() {
    print_step "Checking commit readiness..."

    docker exec $LAB_PEER0 peer lifecycle chaincode checkcommitreadiness \
        --channelID $CHANNEL_NAME \
        --name $CC_NAME \
        --version $CC_VERSION \
        --sequence $CC_SEQUENCE \
        --tls \
        --cafile $ORDERER_CA \
        --output json

    echo ""
}

# Commit chaincode
commit_chaincode() {
    print_step "Committing chaincode definition..."

    LAB_TLS_CERT="${CHAIN_DIR}/crypto-config/peerOrganizations/lab.${CHAIN_TYPE}.dfir.local/peers/${LAB_PEER0}/tls/ca.crt"
    COURT_TLS_CERT="${CHAIN_DIR}/crypto-config/peerOrganizations/court.${CHAIN_TYPE}.dfir.local/peers/${COURT_PEER0}/tls/ca.crt"

    if [ "$CHAIN_TYPE" = "hot" ]; then
        # Hot chain: Only ForensicLabMSP endorsement required (CourtMSP is read-only)
        print_status "Hot chain commit - only ForensicLabMSP endorsement required"
        docker exec $LAB_PEER0 peer lifecycle chaincode commit \
            -o $ORDERER_ADDRESS \
            --channelID $CHANNEL_NAME \
            --name $CC_NAME \
            --version $CC_VERSION \
            --sequence $CC_SEQUENCE \
            --tls \
            --cafile $ORDERER_CA \
            --peerAddresses $LAB_PEER0:$(echo $LAB_PEER0 | grep -o '[0-9]*$' || echo 7051) \
            --tlsRootCertFiles $LAB_TLS_CERT \
            --waitForEvent
    else
        # Cold chain: Both ForensicLabMSP and CourtMSP endorsement required
        docker exec $LAB_PEER0 peer lifecycle chaincode commit \
            -o $ORDERER_ADDRESS \
            --channelID $CHANNEL_NAME \
            --name $CC_NAME \
            --version $CC_VERSION \
            --sequence $CC_SEQUENCE \
            --tls \
            --cafile $ORDERER_CA \
            --peerAddresses $LAB_PEER0:$(echo $LAB_PEER0 | grep -o '[0-9]*$' || echo 7051) \
            --tlsRootCertFiles $LAB_TLS_CERT \
            --peerAddresses $COURT_PEER0:$(echo $COURT_PEER0 | grep -o '[0-9]*$' || echo 8051) \
            --tlsRootCertFiles $COURT_TLS_CERT \
            --waitForEvent
    fi

    print_status "Chaincode committed successfully"
    echo ""
}

# Verify deployment
verify_deployment() {
    print_step "Verifying chaincode deployment..."

    # Query committed chaincode
    print_status "Querying committed chaincode..."
    docker exec $LAB_PEER0 peer lifecycle chaincode querycommitted \
        --channelID $CHANNEL_NAME \
        --name $CC_NAME

    echo ""

    # Initialize chaincode (call Init if needed)
    print_status "Initializing chaincode..."
    docker exec $LAB_PEER0 peer chaincode invoke \
        -o $ORDERER_ADDRESS \
        --tls \
        --cafile $ORDERER_CA \
        -C $CHANNEL_NAME \
        -n $CC_NAME \
        -c '{"function":"Init","Args":[]}' \
        --waitForEvent

    print_status "Chaincode initialized"
    echo ""
}

# Display summary
display_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Chaincode Deployed Successfully${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    print_status "Deployment Summary:"
    echo "  Chain: ${CHAIN_TYPE}"
    echo "  Channel: ${CHANNEL_NAME}"
    echo "  Chaincode: ${CC_NAME}"
    echo "  Version: ${CC_VERSION}"
    echo "  Package ID: ${PACKAGE_ID}"
    echo ""

    print_status "Installed on peers:"
    echo "  ForensicLabMSP:"
    echo "    - $LAB_PEER0"
    echo "    - $LAB_PEER1"
    echo "  CourtMSP:"
    echo "    - $COURT_PEER0"
    echo "    - $COURT_PEER1"
    echo ""

    print_status "Next steps:"
    echo "  1. Test chaincode: ./scripts/test/test-chaincode.sh ${CHAIN_TYPE}"
    echo "  2. View chaincode logs: docker logs -f $LAB_PEER0"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    package_chaincode
    install_lab_peers
    install_court_peers
    get_package_id
    approve_lab
    approve_court
    check_commit_readiness
    commit_chaincode
    verify_deployment
    display_summary
}

# Run main function
main "$@"
