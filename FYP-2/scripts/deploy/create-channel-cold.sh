#!/bin/bash
#
# Create and Join Channel for Cold Chain
# This script creates the evidence-cold channel and joins all peers
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
COLD_CHAIN_DIR="${PROJECT_ROOT}/fabric-network/cold-chain"

# Channel configuration
CHANNEL_NAME="evidence-cold"
ORDERER_ADDRESS="orderer0.orderer.cold.dfir.local:8050"
ORDERER_CA="${COLD_CHAIN_DIR}/crypto-config/ordererOrganizations/orderer.cold.dfir.local/orderers/orderer0.orderer.cold.dfir.local/msp/tlscacerts/tlsca.orderer.cold.dfir.local-cert.pem"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Creating Cold Chain Channel${NC}"
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

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."

    # Check if channel transaction exists
    if [ ! -f "${COLD_CHAIN_DIR}/channel-artifacts/${CHANNEL_NAME}.tx" ]; then
        print_error "Channel transaction file not found. Please run generate-artifacts.sh first."
        exit 1
    fi

    # Check if network is running
    if ! docker ps | grep -q "peer0.lab.cold.dfir.local"; then
        print_error "Cold chain network is not running. Please run start-cold-chain.sh first."
        exit 1
    fi

    print_status "Prerequisites check passed"
    echo ""
}

# Create channel
create_channel() {
    print_step "Creating channel: ${CHANNEL_NAME}"

    # Use peer from lab container to create channel
    docker exec peer0.lab.cold.dfir.local peer channel create \
        -o ${ORDERER_ADDRESS} \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/channel-artifacts/${CHANNEL_NAME}.tx \
        --outputBlock /etc/hyperledger/channel-artifacts/${CHANNEL_NAME}.block \
        --tls \
        --cafile ${ORDERER_CA}

    if [ $? -eq 0 ]; then
        print_status "Channel '${CHANNEL_NAME}' created successfully"
    else
        print_error "Failed to create channel"
        exit 1
    fi

    echo ""
}

# Join ForensicLabMSP peers to channel
join_lab_peers() {
    print_step "Joining ForensicLabMSP peers to channel..."

    # Join peer0.lab
    print_status "Joining peer0.lab.cold.dfir.local..."
    docker exec peer0.lab.cold.dfir.local peer channel join \
        -b /etc/hyperledger/channel-artifacts/${CHANNEL_NAME}.block

    # Join peer1.lab
    print_status "Joining peer1.lab.cold.dfir.local..."
    docker exec peer1.lab.cold.dfir.local peer channel join \
        -b /etc/hyperledger/channel-artifacts/${CHANNEL_NAME}.block

    print_status "ForensicLabMSP peers joined successfully"
    echo ""
}

# Join CourtMSP peers to channel
join_court_peers() {
    print_step "Joining CourtMSP peers to channel..."

    # Copy channel block to court peer
    docker cp peer0.lab.cold.dfir.local:/etc/hyperledger/channel-artifacts/${CHANNEL_NAME}.block \
        ${COLD_CHAIN_DIR}/channel-artifacts/${CHANNEL_NAME}.block

    # Join peer0.court
    print_status "Joining peer0.court.cold.dfir.local..."
    docker exec peer0.court.cold.dfir.local peer channel join \
        -b /etc/hyperledger/channel-artifacts/${CHANNEL_NAME}.block

    # Join peer1.court
    print_status "Joining peer1.court.cold.dfir.local..."
    docker exec peer1.court.cold.dfir.local peer channel join \
        -b /etc/hyperledger/channel-artifacts/${CHANNEL_NAME}.block

    print_status "CourtMSP peers joined successfully"
    echo ""
}

# Update anchor peers
update_anchor_peers() {
    print_step "Updating anchor peers..."

    # Update ForensicLabMSP anchor peer
    print_status "Updating ForensicLabMSP anchor peer..."
    docker exec peer0.lab.cold.dfir.local peer channel update \
        -o ${ORDERER_ADDRESS} \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/channel-artifacts/ForensicLabMSPanchors.tx \
        --tls \
        --cafile ${ORDERER_CA}

    # Update CourtMSP anchor peer
    print_status "Updating CourtMSP anchor peer..."
    docker exec peer0.court.cold.dfir.local peer channel update \
        -o ${ORDERER_ADDRESS} \
        -c ${CHANNEL_NAME} \
        -f /etc/hyperledger/channel-artifacts/CourtMSPanchors.tx \
        --tls \
        --cafile ${ORDERER_CA}

    print_status "Anchor peers updated successfully"
    echo ""
}

# Verify channel
verify_channel() {
    print_step "Verifying channel membership..."

    # Check Lab peers
    print_status "Checking ForensicLabMSP peers..."
    docker exec peer0.lab.cold.dfir.local peer channel list
    echo ""

    # Check Court peers
    print_status "Checking CourtMSP peers..."
    docker exec peer0.court.cold.dfir.local peer channel list
    echo ""
}

# Display summary
display_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Channel Created Successfully${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    print_status "Channel: ${CHANNEL_NAME}"
    echo ""
    echo "Joined Peers:"
    echo "  ForensicLabMSP:"
    echo "    - peer0.lab.cold.dfir.local:9051"
    echo "    - peer1.lab.cold.dfir.local:9053"
    echo ""
    echo "  CourtMSP:"
    echo "    - peer0.court.cold.dfir.local:10051"
    echo "    - peer1.court.cold.dfir.local:10053"
    echo ""

    print_status "Next steps:"
    echo "  1. Deploy chaincode: ./scripts/deploy/deploy-chaincode.sh cold"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    create_channel
    join_lab_peers
    join_court_peers
    update_anchor_peers
    verify_channel
    display_summary
}

# Run main function
main "$@"
