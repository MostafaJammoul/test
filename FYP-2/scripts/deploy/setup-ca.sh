#!/bin/bash
#
# Setup script for Fabric Certificate Authorities and Crypto Material Generation
# This script initializes the PKI infrastructure for both hot and cold chains
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

# Fabric binaries path (update this based on your installation)
FABRIC_BIN_PATH="${PROJECT_ROOT}/fabric-network/bin"
CRYPTOGEN="${FABRIC_BIN_PATH}/cryptogen"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Blockchain DFIR - CA Setup${NC}"
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

# Check if cryptogen binary exists
check_prerequisites() {
    print_status "Checking prerequisites..."

    if [ ! -f "$CRYPTOGEN" ]; then
        print_error "cryptogen binary not found at $CRYPTOGEN"
        print_warning "Please download Hyperledger Fabric binaries:"
        print_warning "  curl -sSL https://bit.ly/2ysbOFE | bash -s -- 3.0.0 1.5.7"
        exit 1
    fi

    print_status "Prerequisites check completed"
}

# Generate crypto materials for hot chain
generate_hot_chain_crypto() {
    print_status "Generating crypto materials for Hot Chain..."

    HOT_CHAIN_DIR="${PROJECT_ROOT}/fabric-network/hot-chain"
    cd "$HOT_CHAIN_DIR"

    # Remove old crypto materials if they exist
    if [ -d "crypto-config" ]; then
        print_warning "Removing existing crypto-config for hot chain..."
        rm -rf crypto-config
    fi

    # Generate crypto materials
    "$CRYPTOGEN" generate --config=config/crypto-config.yaml --output=crypto-config

    if [ $? -eq 0 ]; then
        print_status "Hot chain crypto materials generated successfully"
    else
        print_error "Failed to generate hot chain crypto materials"
        exit 1
    fi
}

# Generate crypto materials for cold chain
generate_cold_chain_crypto() {
    print_status "Generating crypto materials for Cold Chain..."

    COLD_CHAIN_DIR="${PROJECT_ROOT}/fabric-network/cold-chain"
    cd "$COLD_CHAIN_DIR"

    # Remove old crypto materials if they exist
    if [ -d "crypto-config" ]; then
        print_warning "Removing existing crypto-config for cold chain..."
        rm -rf crypto-config
    fi

    # Generate crypto materials
    "$CRYPTOGEN" generate --config=config/crypto-config.yaml --output=crypto-config

    if [ $? -eq 0 ]; then
        print_status "Cold chain crypto materials generated successfully"
    else
        print_error "Failed to generate cold chain crypto materials"
        exit 1
    fi
}

# Set permissions for crypto materials
set_permissions() {
    print_status "Setting appropriate permissions for crypto materials..."

    # Hot chain
    chmod -R 755 "${PROJECT_ROOT}/fabric-network/hot-chain/crypto-config"
    find "${PROJECT_ROOT}/fabric-network/hot-chain/crypto-config" -type f -name "*_sk" -exec chmod 600 {} \;

    # Cold chain
    chmod -R 755 "${PROJECT_ROOT}/fabric-network/cold-chain/crypto-config"
    find "${PROJECT_ROOT}/fabric-network/cold-chain/crypto-config" -type f -name "*_sk" -exec chmod 600 {} \;

    print_status "Permissions set successfully"
}

# Create directory structure for channel artifacts
prepare_channel_artifacts() {
    print_status "Preparing channel artifacts directories..."

    mkdir -p "${PROJECT_ROOT}/fabric-network/hot-chain/channel-artifacts"
    mkdir -p "${PROJECT_ROOT}/fabric-network/cold-chain/channel-artifacts"

    print_status "Channel artifacts directories created"
}

# Display summary
display_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}CA Setup Complete${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    print_status "Summary:"
    echo "  - Hot Chain crypto materials: ${PROJECT_ROOT}/fabric-network/hot-chain/crypto-config"
    echo "  - Cold Chain crypto materials: ${PROJECT_ROOT}/fabric-network/cold-chain/crypto-config"
    echo ""
    print_status "Organizations configured:"
    echo "  - OrdererOrg (3 orderers per chain)"
    echo "  - ForensicLabMSP (2 peers per chain, 5 users for hot, 3 for cold)"
    echo "  - CourtMSP (2 peers per chain, 3 users per chain)"
    echo ""
    print_status "Next steps:"
    echo "  1. Review generated certificates in crypto-config directories"
    echo "  2. Generate genesis block and channel configuration: ./scripts/deploy/generate-artifacts.sh"
    echo "  3. Start the networks: ./scripts/deploy/start-hot-chain.sh"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    generate_hot_chain_crypto
    generate_cold_chain_crypto
    set_permissions
    prepare_channel_artifacts
    display_summary
}

# Run main function
main "$@"
