#!/bin/bash
#
# Chain of Custody - Blockchain System Startup Script
# Digital Forensics Evidence Management System
# American University of Beirut - FYP
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "  Chain of Custody - Blockchain System"
echo "  Starting All Services..."
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check Docker
print_status "Checking Docker..."
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi
print_success "Docker is running"

# Start Hot Chain Network
print_status "Starting Hot Chain Network..."
cd "$SCRIPT_DIR/hot-chain/docker"
docker compose up -d 2>&1 | grep -E "(Creating|Started|Running)" || true
cd "$SCRIPT_DIR"
print_success "Hot Chain Network started"

# Start Cold Chain Network
print_status "Starting Cold Chain Network..."
cd "$SCRIPT_DIR/cold-chain/docker"
docker compose up -d 2>&1 | grep -E "(Creating|Started|Running)" || true
cd "$SCRIPT_DIR"
print_success "Cold Chain Network started"

# Wait for networks to initialize
print_status "Waiting for networks to initialize (15 seconds)..."
sleep 15

# Start Chaincode Services
print_status "Starting Chaincode Services..."
cd "$SCRIPT_DIR"
docker compose -f chaincode-services.yaml up -d 2>&1 | grep -E "(Creating|Started|Running)" || true
print_success "Chaincode Services started"

# Start Explorer
print_status "Starting Hyperledger Explorer..."
cd "$SCRIPT_DIR/explorer"
docker compose -f docker-compose-explorer.yaml up -d 2>&1 | grep -E "(Creating|Started|Running)" || true
print_success "Hyperledger Explorer started"

# Wait for Explorer to initialize
sleep 5

# Start API Server
print_status "Starting API Server..."
pkill -f "api-server.py" 2>/dev/null || true
cd "$SCRIPT_DIR/explorer"
nohup python3 api-server.py > /tmp/coc-api.log 2>&1 &
echo $! > /tmp/coc-api.pid
print_success "API Server started on port 5000"

# Start GUI Server
print_status "Starting GUI Server..."
pkill -f "http.server 8083" 2>/dev/null || true
cd "$SCRIPT_DIR/explorer/gui"
nohup python3 -m http.server 8083 --bind 0.0.0.0 > /tmp/coc-gui.log 2>&1 &
echo $! > /tmp/coc-gui.pid
print_success "GUI Server started on port 8083"

# Start Detailed Blockchain Explorer
print_status "Starting Detailed Blockchain Explorer..."
pkill -f "block-explorer-api.py" 2>/dev/null || true
cd "$SCRIPT_DIR/detailed-explorer"
nohup python3 block-explorer-api.py > /tmp/detailed-explorer.log 2>&1 &
echo $! > /tmp/detailed-explorer.pid
sleep 2
print_success "Detailed Blockchain Explorer started on port 3001"

# Generate Monitor Page
print_status "Generating Blockchain Monitor..."
cd "$SCRIPT_DIR/explorer"
if [ -f "generate-monitor.sh" ]; then
    ./generate-monitor.sh > /dev/null 2>&1 || true
fi

echo ""
echo "=============================================="
echo -e "${GREEN}  All Services Started Successfully!${NC}"
echo "=============================================="
echo ""
echo "Access Points:"
echo "  - Management GUI:           http://localhost:8083"
echo "  - API Server:               http://localhost:5000"
echo "  - Detailed Block Explorer:  http://localhost:3001"
echo "  - Hot Chain Explorer:       http://localhost:8081"
echo "  - Cold Chain Explorer:      http://localhost:8082"
echo ""
echo "Explorer Credentials:"
echo "  - Username: exploreradmin"
echo "  - Password: exploreradminpw"
echo ""
echo "To stop all services: ./stop-all.sh"
echo "=============================================="

# Show container status
echo ""
print_status "Running Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(hot|cold|coc|explorer)" | head -20
