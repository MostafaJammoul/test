#!/bin/sh
#
# IPFS Lab Node Initialization Script
# Configures the node for private network operation
#

set -e

# Remove default bootstrap nodes (disconnect from public IPFS)
ipfs bootstrap rm --all

# Configure private network
# Use environment variable SWARM_KEY for private network
if [ -n "$SWARM_KEY" ]; then
    echo "$SWARM_KEY" > /data/ipfs/swarm.key
fi

# Disable public gateway
ipfs config --json Gateway.NoFetch true
ipfs config --json Gateway.PublicGateways null

# Configure API and gateway addresses
ipfs config Addresses.API /ip4/0.0.0.0/tcp/5001
ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080

# Enable experimental features
ipfs config --json Experimental.FilestoreEnabled true
ipfs config --json Experimental.UrlstoreEnabled true

# Optimize for server profile
ipfs config profile apply server

# Set storage limits
ipfs config Datastore.StorageMax "2TB"

# Configure swarm settings for private network
ipfs config --json Swarm.ConnMgr.HighWater 50
ipfs config --json Swarm.ConnMgr.LowWater 20

# Enable CORS for cluster access
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["GET", "POST"]'

echo "Lab IPFS node configured for private network"
