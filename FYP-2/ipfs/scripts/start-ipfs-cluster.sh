#!/bin/bash
#
# Start Private IPFS Cluster
# Starts all 4 IPFS nodes and cluster peers
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_CONFIG_DIR="$(cd "$SCRIPT_DIR/../cluster-config" && pwd)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Starting Private IPFS Cluster${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if swarm key exists
if [ ! -f "$CLUSTER_CONFIG_DIR/swarm.key" ]; then
    echo -e "${RED}[ERROR]${NC} Swarm key not found. Please run generate-swarm-key.sh first"
    exit 1
fi

if [ ! -f "$CLUSTER_CONFIG_DIR/.env" ]; then
    echo -e "${RED}[ERROR]${NC} .env file not found. Please run generate-swarm-key.sh first"
    exit 1
fi

# Make init scripts executable
chmod +x "$SCRIPT_DIR"/ipfs-init-*.sh

# Export swarm key
export SWARM_KEY=$(<"$CLUSTER_CONFIG_DIR/swarm.key")

echo -e "${GREEN}[INFO]${NC} Starting IPFS cluster nodes..."

# Start the cluster
cd "$CLUSTER_CONFIG_DIR"
docker-compose -f docker-compose-ipfs.yaml up -d

# Wait for nodes to initialize
echo -e "${YELLOW}[INFO]${NC} Waiting for nodes to initialize (30 seconds)..."
sleep 30

# Check cluster status
echo ""
echo -e "${GREEN}[INFO]${NC} Checking cluster status..."
echo ""

# Check each node
for node in lab court redundant replica; do
    echo -e "${GREEN}Checking ipfs-${node}:${NC}"
    docker exec "ipfs-${node}" ipfs id 2>/dev/null || echo -e "${RED}Failed to get node ID${NC}"
    echo ""
done

# Check cluster peers
echo -e "${GREEN}[INFO]${NC} Checking cluster peers..."
docker exec ipfs-cluster-lab ipfs-cluster-ctl peers ls 2>/dev/null || echo -e "${YELLOW}Cluster not fully initialized yet${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}IPFS Cluster Started${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Node endpoints:"
echo "  Lab:       http://localhost:5001 (API), http://localhost:8080 (Gateway)"
echo "  Court:     http://localhost:5011 (API), http://localhost:8081 (Gateway)"
echo "  Redundant: http://localhost:5021 (API), http://localhost:8082 (Gateway)"
echo "  Replica:   http://localhost:5031 (API), http://localhost:8083 (Gateway)"
echo ""
echo "Cluster API endpoints:"
echo "  Lab:       http://localhost:9094"
echo "  Court:     http://localhost:9096"
echo "  Redundant: http://localhost:9098"
echo "  Replica:   http://localhost:9100"
echo ""
echo "To stop the cluster: docker-compose -f $CLUSTER_CONFIG_DIR/docker-compose-ipfs.yaml down"
