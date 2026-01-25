#!/bin/bash
#
# Chain of Custody - Blockchain Reset Script
# Resets the blockchain to a clean state (genesis block only)
#
# Usage:
#   ./reset-blockchain.sh           - Reset only (manual restart required)
#   ./reset-blockchain.sh --restart - Reset and automatically restart with fresh deployment
#   ./reset-blockchain.sh -r        - Same as --restart
#
# WARNING: This will DELETE all blockchain data!
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Flags
AUTO_RESTART=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --restart|-r)
            AUTO_RESTART=true
            shift
            ;;
        --help|-h)
            echo "Chain of Custody - Blockchain Reset Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --restart, -r    Automatically restart and redeploy after reset"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0               # Reset only (manual restart required)"
            echo "  $0 --restart     # Reset and auto-restart with fresh deployment"
            exit 0
            ;;
    esac
done

print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

echo "=============================================="
echo -e "${RED}  Chain of Custody - Blockchain Reset${NC}"
echo "=============================================="
echo ""
echo -e "${YELLOW}WARNING: This will DELETE ALL blockchain data!${NC}"
echo -e "${YELLOW}The network will be reset to genesis block only.${NC}"
if [ "$AUTO_RESTART" = true ]; then
    echo -e "${CYAN}Auto-restart mode: Network will be restarted after reset${NC}"
fi
echo ""

# Confirm
read -p "Are you sure you want to reset the blockchain? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""

# Stop all services first
print_status "Stopping all services..."

# Stop Python servers
pkill -f "api-server.py" 2>/dev/null || true
pkill -f "block-explorer-api.py" 2>/dev/null || true
pkill -f "http.server 8083" 2>/dev/null || true
rm -f /tmp/coc-api.pid /tmp/coc-gui.pid /tmp/detailed-explorer.pid

# Stop Explorer
cd "$SCRIPT_DIR/explorer" 2>/dev/null && docker compose -f docker-compose-explorer.yaml down -v 2>/dev/null || true

# Stop Chaincode Services
cd "$SCRIPT_DIR" && docker compose -f chaincode-services.yaml down -v 2>/dev/null || true

print_success "Services stopped"

# Reset Hot Chain
print_status "Resetting Hot Chain..."
cd "$SCRIPT_DIR/hot-chain/docker"

# Stop containers and remove volumes
docker compose down -v 2>/dev/null || true

# Remove any leftover chaincode containers
docker ps -a --format '{{.Names}}' | grep -E "dev-peer.*hot" | xargs -r docker rm -f 2>/dev/null || true

# Remove chaincode images
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "dev-peer.*hot" | xargs -r docker rmi -f 2>/dev/null || true

print_success "Hot Chain reset"

# Reset Cold Chain
print_status "Resetting Cold Chain..."
cd "$SCRIPT_DIR/cold-chain/docker"

# Stop containers and remove volumes
docker compose down -v 2>/dev/null || true

# Remove any leftover chaincode containers
docker ps -a --format '{{.Names}}' | grep -E "dev-peer.*cold" | xargs -r docker rm -f 2>/dev/null || true

# Remove chaincode images
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "dev-peer.*cold" | xargs -r docker rmi -f 2>/dev/null || true

print_success "Cold Chain reset"

# Clean up networks
print_status "Cleaning up Docker networks..."
docker network prune -f 2>/dev/null || true
print_success "Networks cleaned"

# Clean up temp files
print_status "Cleaning up temporary files..."
rm -f /tmp/block_*.block /tmp/block_*.json /tmp/tx_block.block 2>/dev/null || true
rm -f /tmp/coc-*.log /tmp/detailed-explorer.log 2>/dev/null || true
rm -f "$SCRIPT_DIR/coc.tar.gz" 2>/dev/null || true
print_success "Temp files cleaned"

# Clean up channel artifacts if they exist (for fresh channel creation)
print_status "Cleaning up channel artifacts..."
rm -f "$SCRIPT_DIR/hot-chain/channel-artifacts/"*.block 2>/dev/null || true
rm -f "$SCRIPT_DIR/cold-chain/channel-artifacts/"*.block 2>/dev/null || true
print_success "Channel artifacts cleaned"

echo ""
echo "=============================================="
echo -e "${GREEN}  Blockchain Reset Complete!${NC}"
echo "=============================================="
echo ""

if [ "$AUTO_RESTART" = true ]; then
    echo -e "${CYAN}Starting automatic restart and deployment...${NC}"
    echo ""

    # Start the network
    print_status "Starting blockchain network..."
    cd "$SCRIPT_DIR"
    ./start-all.sh

    echo ""
    print_status "Waiting for network to fully initialize (20 seconds)..."
    sleep 20

    # Create channels
    print_status "Creating channels on both chains..."
    cd "$SCRIPT_DIR/scripts"

    if [ -f "setup-network.sh" ]; then
        echo "Creating Hot Chain channel..."
        ./setup-network.sh channel hot 2>&1 || print_warning "Hot channel may already exist"
        sleep 5

        echo "Creating Cold Chain channel..."
        ./setup-network.sh channel cold 2>&1 || print_warning "Cold channel may already exist"
        sleep 5

        echo "Joining peers to Hot Chain..."
        ./setup-network.sh join hot 2>&1 || print_warning "Peers may already be joined to hot channel"
        sleep 3

        echo "Joining peers to Cold Chain..."
        ./setup-network.sh join cold 2>&1 || print_warning "Peers may already be joined to cold channel"
        sleep 3
    else
        print_warning "setup-network.sh not found. Channels may need manual creation."
    fi

    # Deploy chaincode
    print_status "Deploying chaincode to both chains..."
    if [ -f "deploy-chaincode.sh" ]; then
        ./deploy-chaincode.sh deploy 2>&1 || print_warning "Chaincode deployment encountered issues"
    else
        print_warning "deploy-chaincode.sh not found. Chaincode may need manual deployment."
    fi

    # Wait for everything to settle
    sleep 5

    # Verify deployment
    print_status "Verifying deployment..."
    echo ""
    echo "Hot Chain Status:"
    curl -s http://localhost:3001/api/hot/info 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  Height: {d.get(\"height\", \"N/A\")}')" || echo "  API not responding"

    echo "Cold Chain Status:"
    curl -s http://localhost:3001/api/cold/info 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  Height: {d.get(\"height\", \"N/A\")}')" || echo "  API not responding"

    echo ""
    echo "=============================================="
    echo -e "${GREEN}  Fresh Blockchain Ready!${NC}"
    echo "=============================================="
    echo ""
    echo "The blockchain has been reset and restarted with:"
    echo "  - Fresh genesis blocks on both chains"
    echo "  - Channels created and peers joined"
    echo "  - Chaincode deployed and ready"
    echo "  - All services running"
    echo ""
    echo "Access Points:"
    echo "  - Management GUI:           http://localhost:8083"
    echo "  - API Server:               http://localhost:5000"
    echo "  - Detailed Block Explorer:  http://localhost:3001"
    echo "  - Hot Chain Explorer:       http://localhost:8081"
    echo "  - Cold Chain Explorer:      http://localhost:8082"
    echo ""
else
    echo "The blockchain has been reset to a clean state."
    echo "When you start the network again, it will begin"
    echo "with only the genesis block."
    echo ""
    echo "To start fresh:"
    echo "  1. Run: ./start-all.sh"
    echo "  2. Wait for network to initialize (30 seconds)"
    echo "  3. Run: ./scripts/setup-network.sh"
    echo ""
    echo "Or use the quick restart command:"
    echo "  ./reset-blockchain.sh --restart"
    echo ""
fi
