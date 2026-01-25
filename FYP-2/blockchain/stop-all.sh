#!/bin/bash
#
# Chain of Custody - Blockchain System Shutdown Script
# Digital Forensics Evidence Management System
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "  Chain of Custody - Blockchain System"
echo "  Stopping All Services..."
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# Stop API Server
print_status "Stopping API Server..."
if [ -f /tmp/coc-api.pid ]; then
    kill $(cat /tmp/coc-api.pid) 2>/dev/null || true
    rm -f /tmp/coc-api.pid
fi
pkill -f "api-server.py" 2>/dev/null || true
print_success "API Server stopped"

# Stop GUI Server
print_status "Stopping GUI Server..."
if [ -f /tmp/coc-gui.pid ]; then
    kill $(cat /tmp/coc-gui.pid) 2>/dev/null || true
    rm -f /tmp/coc-gui.pid
fi
pkill -f "http.server 8083" 2>/dev/null || true
print_success "GUI Server stopped"

# Stop Detailed Blockchain Explorer
print_status "Stopping Detailed Blockchain Explorer..."
if [ -f /tmp/detailed-explorer.pid ]; then
    kill $(cat /tmp/detailed-explorer.pid) 2>/dev/null || true
    rm -f /tmp/detailed-explorer.pid
fi
pkill -f "block-explorer-api.py" 2>/dev/null || true
print_success "Detailed Blockchain Explorer stopped"

# Stop Explorer
print_status "Stopping Hyperledger Explorer..."
cd "$SCRIPT_DIR/explorer"
docker compose -f docker-compose-explorer.yaml down 2>&1 | grep -v "Warning" || true
print_success "Hyperledger Explorer stopped"

# Stop Chaincode Services
print_status "Stopping Chaincode Services..."
cd "$SCRIPT_DIR"
docker compose -f chaincode-services.yaml down 2>&1 | grep -v "Warning" || true
print_success "Chaincode Services stopped"

# Stop Cold Chain Network
print_status "Stopping Cold Chain Network..."
cd "$SCRIPT_DIR/cold-chain/docker"
docker compose down 2>&1 | grep -v "Warning" || true
print_success "Cold Chain Network stopped"

# Stop Hot Chain Network
print_status "Stopping Hot Chain Network..."
cd "$SCRIPT_DIR/hot-chain/docker"
docker compose down 2>&1 | grep -v "Warning" || true
print_success "Hot Chain Network stopped"

echo ""
echo "=============================================="
echo -e "${GREEN}  All Services Stopped Successfully!${NC}"
echo "=============================================="
echo ""
echo "To start again: ./start-all.sh"
echo ""

# Verify all containers are stopped
remaining=$(docker ps --format "{{.Names}}" | grep -E "(hot|cold|coc|explorer)" | wc -l)
if [ "$remaining" -gt 0 ]; then
    echo -e "${YELLOW}Note: Some containers may still be running:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(hot|cold|coc|explorer)"
else
    echo "All blockchain containers have been stopped."
fi
