#!/bin/bash
#
# Complete Blockchain Deployment Script
# This script runs all deployment steps in order
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}Complete DFIR Blockchain Deployment${NC}"
echo -e "${GREEN}============================================================${NC}"
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

print_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# Check if Docker is accessible
check_docker() {
    if ! docker ps > /dev/null 2>&1; then
        print_error "Docker is not accessible. Please ensure:"
        echo "  1. Docker is installed"
        echo "  2. Docker service is running: sudo systemctl start docker"
        echo "  3. You are in the docker group: newgrp docker"
        exit 1
    fi
}

# Prompt user for deployment choice
prompt_deployment_choice() {
    echo ""
    print_status "Deployment Options:"
    echo "  1. Deploy Hot Chain only (recommended for testing)"
    echo "  2. Deploy Hot Chain + Cold Chain (complete system)"
    echo ""
    read -p "Enter your choice (1 or 2): " CHOICE
    echo ""

    if [ "$CHOICE" = "1" ]; then
        DEPLOY_COLD=false
        print_status "Will deploy: Hot Chain only"
    elif [ "$CHOICE" = "2" ]; then
        DEPLOY_COLD=true
        print_status "Will deploy: Hot Chain + Cold Chain"
    else
        print_error "Invalid choice. Defaulting to Hot Chain only."
        DEPLOY_COLD=false
    fi
    echo ""
}

# Step 1: Generate crypto materials
step1_crypto() {
    print_step "Step 1/10: Generating Crypto Materials"
    echo ""

    cd "$PROJECT_ROOT"
    ./scripts/deploy/setup-ca.sh

    print_success "Crypto materials generated"
    echo ""
    sleep 2
}

# Step 2: Generate channel artifacts
step2_artifacts() {
    print_step "Step 2/10: Generating Channel Artifacts"
    echo ""

    cd "$PROJECT_ROOT"
    ./scripts/deploy/generate-artifacts.sh

    print_success "Channel artifacts generated"
    echo ""
    sleep 2
}

# Step 3: Start hot chain network
step3_hot_network() {
    print_step "Step 3/10: Starting Hot Chain Network"
    echo ""

    cd "$PROJECT_ROOT"
    ./scripts/deploy/start-hot-chain.sh

    print_success "Hot chain network started"
    echo ""
    sleep 5
}

# Step 4: Create hot chain channel
step4_hot_channel() {
    print_step "Step 4/10: Creating Hot Chain Channel"
    echo ""

    cd "$PROJECT_ROOT"
    ./scripts/deploy/create-channel-hot.sh

    print_success "Hot chain channel created"
    echo ""
    sleep 2
}

# Step 5: Deploy chaincode to hot chain
step5_hot_chaincode() {
    print_step "Step 5/10: Deploying Chaincode to Hot Chain"
    echo ""

    cd "$PROJECT_ROOT"
    ./scripts/deploy/deploy-chaincode.sh hot

    print_success "Chaincode deployed to hot chain"
    echo ""
    sleep 2
}

# Step 6: Test hot chain
step6_test_hot() {
    print_step "Step 6/10: Testing Hot Chain"
    echo ""

    cd "$PROJECT_ROOT"
    ./scripts/test/test-chaincode.sh hot

    print_success "Hot chain tests passed"
    echo ""
    sleep 2
}

# Step 7: Start cold chain network (optional)
step7_cold_network() {
    if [ "$DEPLOY_COLD" = true ]; then
        print_step "Step 7/10: Starting Cold Chain Network"
        echo ""

        cd "$PROJECT_ROOT"
        ./scripts/deploy/start-cold-chain.sh

        print_success "Cold chain network started"
        echo ""
        sleep 5
    else
        print_step "Step 7/10: Skipping Cold Chain Network"
        echo ""
    fi
}

# Step 8: Create cold chain channel (optional)
step8_cold_channel() {
    if [ "$DEPLOY_COLD" = true ]; then
        print_step "Step 8/10: Creating Cold Chain Channel"
        echo ""

        cd "$PROJECT_ROOT"
        ./scripts/deploy/create-channel-cold.sh

        print_success "Cold chain channel created"
        echo ""
        sleep 2
    else
        print_step "Step 8/10: Skipping Cold Chain Channel"
        echo ""
    fi
}

# Step 9: Deploy chaincode to cold chain (optional)
step9_cold_chaincode() {
    if [ "$DEPLOY_COLD" = true ]; then
        print_step "Step 9/10: Deploying Chaincode to Cold Chain"
        echo ""

        cd "$PROJECT_ROOT"
        ./scripts/deploy/deploy-chaincode.sh cold

        print_success "Chaincode deployed to cold chain"
        echo ""
        sleep 2
    else
        print_step "Step 9/10: Skipping Cold Chain Chaincode"
        echo ""
    fi
}

# Step 10: Test cold chain (optional)
step10_test_cold() {
    if [ "$DEPLOY_COLD" = true ]; then
        print_step "Step 10/10: Testing Cold Chain"
        echo ""

        cd "$PROJECT_ROOT"
        ./scripts/test/test-chaincode.sh cold

        print_success "Cold chain tests passed"
        echo ""
    else
        print_step "Step 10/10: Skipping Cold Chain Tests"
        echo ""
    fi
}

# Display final summary
display_summary() {
    echo ""
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo ""

    print_status "Deployed Components:"
    echo ""

    if [ "$DEPLOY_COLD" = true ]; then
        echo "  ${GREEN}✓${NC} Hot Chain (Active Investigations)"
        echo "    - 3 RAFT Orderers"
        echo "    - 4 Peers (2 Lab + 2 Court)"
        echo "    - 4 CouchDB instances"
        echo "    - Channel: evidence-hot"
        echo "    - Chaincode: custody v1.0"
        echo ""
        echo "  ${GREEN}✓${NC} Cold Chain (Archived Evidence)"
        echo "    - 3 RAFT Orderers"
        echo "    - 4 Peers (2 Lab + 2 Court)"
        echo "    - 4 CouchDB instances"
        echo "    - Channel: evidence-cold"
        echo "    - Chaincode: custody v1.0"
        echo ""
        print_status "Total Containers Running: 22"
    else
        echo "  ${GREEN}✓${NC} Hot Chain (Active Investigations)"
        echo "    - 3 RAFT Orderers"
        echo "    - 4 Peers (2 Lab + 2 Court)"
        echo "    - 4 CouchDB instances"
        echo "    - Channel: evidence-hot"
        echo "    - Chaincode: custody v1.0"
        echo ""
        print_status "Total Containers Running: 11"
    fi

    echo ""
    print_status "Chaincode Functions Available:"
    echo "  - CreateEvidence"
    echo "  - TransferCustody"
    echo "  - ArchiveToCold"
    echo "  - ReactivateFromCold"
    echo "  - InvalidateEvidence"
    echo "  - GetEvidenceSummary"
    echo "  - QueryEvidencesByCase"
    echo "  - GetCustodyChain"
    echo ""

    print_status "Access Points:"
    echo ""
    echo "  Hot Chain CouchDB:"
    echo "    - Lab Peer 0:   http://localhost:5984/_utils"
    echo "    - Lab Peer 1:   http://localhost:6984/_utils"
    echo "    - Court Peer 0: http://localhost:7984/_utils"
    echo "    - Court Peer 1: http://localhost:8984/_utils"
    echo "    - Credentials: admin/adminpw"
    echo ""

    if [ "$DEPLOY_COLD" = true ]; then
        echo "  Cold Chain CouchDB:"
        echo "    - Lab Peer 0:   http://localhost:15984/_utils"
        echo "    - Lab Peer 1:   http://localhost:16984/_utils"
        echo "    - Court Peer 0: http://localhost:17984/_utils"
        echo "    - Court Peer 1: http://localhost:18984/_utils"
        echo "    - Credentials: admin/adminpw"
        echo ""
    fi

    print_status "Quick Commands:"
    echo ""
    echo "  View all containers:"
    echo "    docker ps --format 'table {{.Names}}\t{{.Status}}'"
    echo ""
    echo "  View logs:"
    echo "    docker logs -f peer0.lab.hot.dfir.local"
    echo "    docker logs -f orderer0.orderer.hot.dfir.local"
    echo ""
    echo "  Query evidence:"
    echo "    docker exec peer0.lab.hot.dfir.local peer chaincode query \\"
    echo "      -C evidence-hot -n custody \\"
    echo "      -c '{\"function\":\"GetEvidenceSummary\",\"Args\":[\"CASE-ID\",\"EVD-ID\"]}'"
    echo ""
    echo "  Create evidence:"
    echo "    docker exec peer0.lab.hot.dfir.local peer chaincode invoke \\"
    echo "      -o orderer0.orderer.hot.dfir.local:7050 --tls \\"
    echo "      --cafile /etc/hyperledger/orderer/tls/ca.crt \\"
    echo "      -C evidence-hot -n custody \\"
    echo "      -c '{\"function\":\"CreateEvidence\",\"Args\":[...]}' \\"
    echo "      --waitForEvent"
    echo ""

    print_status "Stop Networks:"
    echo ""
    echo "  Hot Chain:"
    echo "    cd ~/FYP-2/fabric-network/hot-chain/docker"
    echo "    docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down"
    echo ""

    if [ "$DEPLOY_COLD" = true ]; then
        echo "  Cold Chain:"
        echo "    cd ~/FYP-2/fabric-network/cold-chain/docker"
        echo "    docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down"
        echo ""
    fi

    print_status "Documentation:"
    echo "  - Quick Start:    ~/FYP-2/BLOCKCHAIN_README.md"
    echo "  - Full Guide:     ~/FYP-2/DEPLOYMENT_GUIDE.md"
    echo "  - Chaincode API:  ~/FYP-2/chaincode/public/README.md"
    echo ""

    echo -e "${GREEN}Your DFIR blockchain is now ready for use!${NC}"
    echo ""
}

# Main execution
main() {
    print_status "This script will deploy the complete DFIR blockchain system"
    print_status "Estimated time: 10-15 minutes"
    echo ""

    # Check Docker access
    check_docker

    # Prompt for deployment choice
    prompt_deployment_choice

    print_status "Starting deployment..."
    echo ""
    sleep 2

    # Execute all steps
    step1_crypto
    step2_artifacts
    step3_hot_network
    step4_hot_channel
    step5_hot_chaincode
    step6_test_hot
    step7_cold_network
    step8_cold_channel
    step9_cold_chaincode
    step10_test_cold

    # Display summary
    display_summary
}

# Error handling
trap 'print_error "Deployment failed at step: $BASH_COMMAND"; exit 1' ERR

# Run main function
main "$@"
