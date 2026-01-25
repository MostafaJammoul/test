#!/bin/bash
#
# Generate Genesis Block and Channel Artifacts
# This script creates the genesis block for orderers and channel configuration transactions
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Fabric binaries path
FABRIC_BIN_PATH="${PROJECT_ROOT}/fabric-network/bin"
CONFIGTXGEN="${FABRIC_BIN_PATH}/configtxgen"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Blockchain DFIR - Generate Artifacts${NC}"
echo -e "${GREEN}========================================${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if configtxgen binary exists
check_prerequisites() {
    print_status "Checking prerequisites..."

    if [ ! -f "$CONFIGTXGEN" ]; then
        print_error "configtxgen binary not found at $CONFIGTXGEN"
        print_warning "Please download Hyperledger Fabric binaries first"
        exit 1
    fi

    # Check if crypto materials exist
    if [ ! -d "${PROJECT_ROOT}/fabric-network/hot-chain/crypto-config" ]; then
        print_error "Hot chain crypto materials not found"
        print_warning "Please run ./scripts/deploy/setup-ca.sh first"
        exit 1
    fi

    if [ ! -d "${PROJECT_ROOT}/fabric-network/cold-chain/crypto-config" ]; then
        print_error "Cold chain crypto materials not found"
        print_warning "Please run ./scripts/deploy/setup-ca.sh first"
        exit 1
    fi

    print_status "Prerequisites check completed"
}

# Generate artifacts for hot chain
generate_hot_chain_artifacts() {
    print_status "Generating artifacts for Hot Chain..."

    HOT_CHAIN_DIR="${PROJECT_ROOT}/fabric-network/hot-chain"
    ARTIFACTS_DIR="${HOT_CHAIN_DIR}/channel-artifacts"

    cd "$HOT_CHAIN_DIR"
    export FABRIC_CFG_PATH="${HOT_CHAIN_DIR}/config"

    # Generate genesis block for orderer
    print_status "  - Generating genesis block for hot chain orderer..."
    "$CONFIGTXGEN" -profile HotChainOrdererGenesis \
        -channelID system-channel \
        -outputBlock "${ARTIFACTS_DIR}/genesis.block"

    if [ $? -ne 0 ]; then
        print_error "Failed to generate hot chain genesis block"
        exit 1
    fi

    # Generate channel configuration transaction
    print_status "  - Generating channel creation transaction for evidence-hot..."
    "$CONFIGTXGEN" -profile EvidenceHotChannel \
        -channelID evidence-hot \
        -outputCreateChannelTx "${ARTIFACTS_DIR}/evidence-hot.tx"

    if [ $? -ne 0 ]; then
        print_error "Failed to generate hot chain channel transaction"
        exit 1
    fi

    # Generate anchor peer transactions
    print_status "  - Generating anchor peer update for ForensicLabMSP..."
    "$CONFIGTXGEN" -profile EvidenceHotChannel \
        -channelID evidence-hot \
        -outputAnchorPeersUpdate "${ARTIFACTS_DIR}/ForensicLabMSPanchors.tx" \
        -asOrg ForensicLabMSP

    print_status "  - Generating anchor peer update for CourtMSP..."
    "$CONFIGTXGEN" -profile EvidenceHotChannel \
        -channelID evidence-hot \
        -outputAnchorPeersUpdate "${ARTIFACTS_DIR}/CourtMSPanchors.tx" \
        -asOrg CourtMSP

    print_status "Hot chain artifacts generated successfully"
}

# Generate artifacts for cold chain
generate_cold_chain_artifacts() {
    print_status "Generating artifacts for Cold Chain..."

    COLD_CHAIN_DIR="${PROJECT_ROOT}/fabric-network/cold-chain"
    ARTIFACTS_DIR="${COLD_CHAIN_DIR}/channel-artifacts"

    cd "$COLD_CHAIN_DIR"
    export FABRIC_CFG_PATH="${COLD_CHAIN_DIR}/config"

    # Generate genesis block for orderer
    print_status "  - Generating genesis block for cold chain orderer..."
    "$CONFIGTXGEN" -profile ColdChainOrdererGenesis \
        -channelID system-channel-cold \
        -outputBlock "${ARTIFACTS_DIR}/genesis.block"

    if [ $? -ne 0 ]; then
        print_error "Failed to generate cold chain genesis block"
        exit 1
    fi

    # Generate channel configuration transaction
    print_status "  - Generating channel creation transaction for evidence-cold..."
    "$CONFIGTXGEN" -profile EvidenceColdChannel \
        -channelID evidence-cold \
        -outputCreateChannelTx "${ARTIFACTS_DIR}/evidence-cold.tx"

    if [ $? -ne 0 ]; then
        print_error "Failed to generate cold chain channel transaction"
        exit 1
    fi

    # Generate anchor peer transactions
    print_status "  - Generating anchor peer update for ForensicLabMSP..."
    "$CONFIGTXGEN" -profile EvidenceColdChannel \
        -channelID evidence-cold \
        -outputAnchorPeersUpdate "${ARTIFACTS_DIR}/ForensicLabMSPanchors.tx" \
        -asOrg ForensicLabMSP

    print_status "  - Generating anchor peer update for CourtMSP..."
    "$CONFIGTXGEN" -profile EvidenceColdChannel \
        -channelID evidence-cold \
        -outputAnchorPeersUpdate "${ARTIFACTS_DIR}/CourtMSPanchors.tx" \
        -asOrg CourtMSP

    print_status "Cold chain artifacts generated successfully"
}

# Inspect generated artifacts
inspect_artifacts() {
    print_status "Inspecting generated artifacts..."

    export FABRIC_CFG_PATH="${PROJECT_ROOT}/fabric-network/hot-chain/config"

    # Inspect hot chain genesis block
    print_status "  - Hot chain genesis block:"
    "$CONFIGTXGEN" -inspectBlock \
        "${PROJECT_ROOT}/fabric-network/hot-chain/channel-artifacts/genesis.block" \
        > "${PROJECT_ROOT}/fabric-network/hot-chain/channel-artifacts/genesis-block-info.json"

    # Inspect hot channel transaction
    print_status "  - Hot chain channel transaction:"
    "$CONFIGTXGEN" -inspectChannelCreateTx \
        "${PROJECT_ROOT}/fabric-network/hot-chain/channel-artifacts/evidence-hot.tx" \
        > "${PROJECT_ROOT}/fabric-network/hot-chain/channel-artifacts/evidence-hot-info.json"

    print_status "Artifact inspection completed"
}

# Display summary
display_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Artifact Generation Complete${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    print_status "Hot Chain Artifacts:"
    echo "  - Genesis Block: fabric-network/hot-chain/channel-artifacts/genesis.block"
    echo "  - Channel TX: fabric-network/hot-chain/channel-artifacts/evidence-hot.tx"
    echo "  - Anchor Peers: ForensicLabMSPanchors.tx, CourtMSPanchors.tx"
    echo ""
    print_status "Cold Chain Artifacts:"
    echo "  - Genesis Block: fabric-network/cold-chain/channel-artifacts/genesis.block"
    echo "  - Channel TX: fabric-network/cold-chain/channel-artifacts/evidence-cold.tx"
    echo "  - Anchor Peers: ForensicLabMSPanchors.tx, CourtMSPanchors.tx"
    echo ""
    print_status "Next steps:"
    echo "  1. Start hot chain: ./scripts/deploy/start-hot-chain.sh"
    echo "  2. Start cold chain: ./scripts/deploy/start-cold-chain.sh"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    generate_hot_chain_artifacts
    generate_cold_chain_artifacts
    inspect_artifacts
    display_summary
}

# Run main function
main "$@"
