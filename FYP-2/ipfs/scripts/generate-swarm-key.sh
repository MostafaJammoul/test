#!/bin/bash
#
# Generate Swarm Key for Private IPFS Network
# This key ensures only authorized nodes can join the cluster
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Generating IPFS Swarm Key...${NC}"

# Generate random 32-byte key
KEY=$(head -c 32 /dev/urandom | base64)

# Create swarm key in libp2p format
SWARM_KEY="/key/swarm/psk/1.0.0/
/base16/
$(echo -n "$KEY" | xxd -p -c 64)"

# Save to file
mkdir -p ../cluster-config
echo "$SWARM_KEY" > ../cluster-config/swarm.key

# Also create .env file for Docker Compose
cat > ../cluster-config/.env <<EOF
# Private IPFS Cluster Configuration
SWARM_KEY=${KEY}
CLUSTER_SECRET=$(head -c 32 /dev/urandom | base64)
EOF

echo -e "${GREEN}Swarm key generated and saved to:${NC}"
echo "  - ../cluster-config/swarm.key"
echo "  - ../cluster-config/.env"
echo ""
echo -e "${YELLOW}IMPORTANT: Keep these files secure and do not commit to version control${NC}"
echo ""
echo "To use the swarm key, set the SWARM_KEY environment variable when starting nodes:"
echo "  export SWARM_KEY=\"\$(<../cluster-config/swarm.key)\""
