#!/bin/bash
#
# Start Hot Chain Network
# This script starts the complete hot chain: orderers, peers, and CouchDB instances
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
HOT_CHAIN_DIR="${PROJECT_ROOT}/fabric-network/hot-chain"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Starting Hot Chain Network${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."

    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi

    # Check if crypto materials exist
    if [ ! -d "${HOT_CHAIN_DIR}/crypto-config" ]; then
        print_error "Crypto materials not found. Please run setup-ca.sh first."
        exit 1
    fi

    # Check if channel artifacts exist
    if [ ! -f "${HOT_CHAIN_DIR}/channel-artifacts/genesis.block" ]; then
        print_error "Genesis block not found. Please run generate-artifacts.sh first."
        exit 1
    fi

    print_status "Prerequisites check passed"
    echo ""
}

# Clean up old containers and volumes
cleanup_old_network() {
    print_step "Cleaning up old hot chain network (if exists)..."

    cd "${HOT_CHAIN_DIR}/docker"

    # Stop and remove containers
    docker-compose -f docker-compose-orderers.yaml down 2>/dev/null || true
    docker-compose -f docker-compose-peers.yaml down 2>/dev/null || true

    # Remove dangling volumes (optional - uncomment to remove)
    # docker volume prune -f

    print_status "Cleanup completed"
    echo ""
}

# Start orderers
start_orderers() {
    print_step "Starting RAFT orderers for hot chain..."

    cd "${HOT_CHAIN_DIR}/docker"

    docker-compose -f docker-compose-orderers.yaml up -d

    if [ $? -eq 0 ]; then
        print_status "Orderers started successfully"
    else
        print_error "Failed to start orderers"
        exit 1
    fi

    echo ""
    print_status "Waiting for orderers to initialize (15 seconds)..."
    sleep 15
    echo ""
}

# Start peers and CouchDB
start_peers() {
    print_step "Starting peers and CouchDB instances..."

    cd "${HOT_CHAIN_DIR}/docker"

    docker-compose -f docker-compose-peers.yaml up -d

    if [ $? -eq 0 ]; then
        print_status "Peers and CouchDB started successfully"
    else
        print_error "Failed to start peers"
        exit 1
    fi

    echo ""
    print_status "Waiting for peers to initialize (20 seconds)..."
    sleep 20
    echo ""
}

# Verify network is running
verify_network() {
    print_step "Verifying hot chain network..."

    # Check orderers
    print_status "Checking orderers..."
    for i in 0 1 2; do
        if docker ps | grep -q "orderer${i}.orderer.hot.dfir.local"; then
            echo -e "  ${GREEN}✓${NC} orderer${i}.orderer.hot.dfir.local is running"
        else
            echo -e "  ${RED}✗${NC} orderer${i}.orderer.hot.dfir.local is NOT running"
        fi
    done
    echo ""

    # Check Lab peers
    print_status "Checking ForensicLabMSP peers..."
    for i in 0 1; do
        if docker ps | grep -q "peer${i}.lab.hot.dfir.local"; then
            echo -e "  ${GREEN}✓${NC} peer${i}.lab.hot.dfir.local is running"
        else
            echo -e "  ${RED}✗${NC} peer${i}.lab.hot.dfir.local is NOT running"
        fi
    done
    echo ""

    # Check Court peers
    print_status "Checking CourtMSP peers..."
    for i in 0 1; do
        if docker ps | grep -q "peer${i}.court.hot.dfir.local"; then
            echo -e "  ${GREEN}✓${NC} peer${i}.court.hot.dfir.local is running"
        else
            echo -e "  ${RED}✗${NC} peer${i}.court.hot.dfir.local is NOT running"
        fi
    done
    echo ""

    # Check CouchDB instances
    print_status "Checking CouchDB instances..."
    for service in couchdb0.lab couchdb1.lab couchdb0.court couchdb1.court; do
        if docker ps | grep -q "${service}.hot.dfir.local"; then
            echo -e "  ${GREEN}✓${NC} ${service}.hot.dfir.local is running"
        else
            echo -e "  ${RED}✗${NC} ${service}.hot.dfir.local is NOT running"
        fi
    done
    echo ""
}

# Display summary
display_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Hot Chain Network Started Successfully${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    print_status "Network Summary:"
    echo ""
    echo "Orderers (RAFT Consensus):"
    echo "  - orderer0.orderer.hot.dfir.local:7050"
    echo "  - orderer1.orderer.hot.dfir.local:7051"
    echo "  - orderer2.orderer.hot.dfir.local:7052"
    echo ""

    echo "ForensicLabMSP Peers:"
    echo "  - peer0.lab.hot.dfir.local:7051"
    echo "  - peer1.lab.hot.dfir.local:7053"
    echo ""

    echo "CourtMSP Peers:"
    echo "  - peer0.court.hot.dfir.local:8051"
    echo "  - peer1.court.hot.dfir.local:8053"
    echo ""

    echo "CouchDB Instances:"
    echo "  - http://localhost:5984 (Lab Peer 0)"
    echo "  - http://localhost:6984 (Lab Peer 1)"
    echo "  - http://localhost:7984 (Court Peer 0)"
    echo "  - http://localhost:8984 (Court Peer 1)"
    echo ""

    print_status "Next steps:"
    echo "  1. Create and join channel: ./scripts/deploy/create-channel-hot.sh"
    echo "  2. Deploy chaincode: ./scripts/deploy/deploy-chaincode.sh hot"
    echo ""

    print_warning "To view logs: docker logs -f <container-name>"
    print_warning "To stop network: cd ${HOT_CHAIN_DIR}/docker && docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    cleanup_old_network
    start_orderers
    start_peers
    verify_network
    display_summary
}

# Run main function
main "$@"
