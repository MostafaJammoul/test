#!/bin/bash

# Chain of Custody Blockchain Network Setup Script
# This script sets up both Hot and Cold chains for the Digital Forensics CoC system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCKCHAIN_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$BLOCKCHAIN_DIR/bin"
HOT_DIR="$BLOCKCHAIN_DIR/hot-chain"
COLD_DIR="$BLOCKCHAIN_DIR/cold-chain"

# Export bin directory to PATH
export PATH="$BIN_DIR:$PATH"

# Fabric version
FABRIC_VERSION="3.0"

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Pull Docker images if not present
pull_docker_images() {
    print_header "Pulling Hyperledger Fabric Docker Images"

    images=(
        "hyperledger/fabric-peer:${FABRIC_VERSION}"
        "hyperledger/fabric-orderer:${FABRIC_VERSION}"
        "hyperledger/fabric-tools:${FABRIC_VERSION}"
        "hyperledger/fabric-ccenv:${FABRIC_VERSION}"
        "hyperledger/fabric-baseos:${FABRIC_VERSION}"
        "couchdb:3.3.3"
    )

    for image in "${images[@]}"; do
        if ! docker image inspect "$image" > /dev/null 2>&1; then
            echo "Pulling $image..."
            docker pull "$image"
        else
            echo "$image already exists"
        fi
    done

    print_success "Docker images ready"
}

# Generate crypto materials for a chain
generate_crypto() {
    local chain=$1
    local chain_dir

    if [ "$chain" == "hot" ]; then
        chain_dir="$HOT_DIR"
    else
        chain_dir="$COLD_DIR"
    fi

    print_header "Generating Crypto Materials for ${chain^^} Chain"

    cd "$chain_dir"

    # Clean existing crypto materials
    rm -rf crypto-config

    # Generate crypto materials
    cryptogen generate --config=config/crypto-config.yaml --output=crypto-config

    if [ $? -eq 0 ]; then
        print_success "Crypto materials generated for ${chain^^} chain"
    else
        print_error "Failed to generate crypto materials for ${chain^^} chain"
        exit 1
    fi
}

# Generate channel artifacts for a chain (Fabric 3.0 compatible)
generate_channel_artifacts() {
    local chain=$1
    local chain_dir
    local channel_name
    local profile_genesis

    if [ "$chain" == "hot" ]; then
        chain_dir="$HOT_DIR"
        channel_name="hotchannel"
        profile_genesis="HotOrdererGenesis"
    else
        chain_dir="$COLD_DIR"
        channel_name="coldchannel"
        profile_genesis="ColdOrdererGenesis"
    fi

    print_header "Generating Channel Artifacts for ${chain^^} Chain"

    cd "$chain_dir"

    # Clean existing artifacts
    rm -rf channel-artifacts
    mkdir -p channel-artifacts

    # Set FABRIC_CFG_PATH to config directory
    export FABRIC_CFG_PATH="$chain_dir/config"

    # Generate genesis block for the application channel (Fabric 3.0 style)
    # In Fabric 3.0, we create the channel genesis block directly
    echo "Generating channel genesis block for $channel_name..."
    configtxgen -profile "$profile_genesis" -channelID "$channel_name" -outputBlock channel-artifacts/${channel_name}.block

    if [ $? -eq 0 ]; then
        print_success "Channel artifacts generated for ${chain^^} chain"
    else
        print_error "Failed to generate channel artifacts for ${chain^^} chain"
        exit 1
    fi
}

# Start the network
start_network() {
    local chain=$1
    local chain_dir

    if [ "$chain" == "hot" ]; then
        chain_dir="$HOT_DIR"
    else
        chain_dir="$COLD_DIR"
    fi

    print_header "Starting ${chain^^} Chain Network"

    cd "$chain_dir/docker"

    # Start containers
    docker compose up -d

    if [ $? -eq 0 ]; then
        print_success "${chain^^} chain network started"
        echo "Waiting for containers to be ready..."
        sleep 10
    else
        print_error "Failed to start ${chain^^} chain network"
        exit 1
    fi
}

# Stop the network
stop_network() {
    local chain=$1
    local chain_dir

    if [ "$chain" == "hot" ]; then
        chain_dir="$HOT_DIR"
    else
        chain_dir="$COLD_DIR"
    fi

    print_header "Stopping ${chain^^} Chain Network"

    cd "$chain_dir/docker"

    docker compose down -v

    print_success "${chain^^} chain network stopped"
}

# Create channel and join peers
create_channel() {
    local chain=$1
    local chain_dir
    local channel_name
    local orderer_address
    local orderer_ca
    local admin_port

    if [ "$chain" == "hot" ]; then
        chain_dir="$HOT_DIR"
        channel_name="hotchannel"
        orderer_address="orderer.hot.coc.com:7050"
        admin_port="7053"
        orderer_ca="$chain_dir/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem"
    else
        chain_dir="$COLD_DIR"
        channel_name="coldchannel"
        orderer_address="orderer.cold.coc.com:8050"
        admin_port="8053"
        orderer_ca="$chain_dir/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem"
    fi

    print_header "Creating Channel for ${chain^^} Chain"

    cd "$chain_dir"

    # Set environment for osnadmin
    export ORDERER_CA="$orderer_ca"
    export ORDERER_ADMIN_TLS_SIGN_CERT="$chain_dir/crypto-config/ordererOrganizations/${chain}.coc.com/orderers/orderer.${chain}.coc.com/tls/server.crt"
    export ORDERER_ADMIN_TLS_PRIVATE_KEY="$chain_dir/crypto-config/ordererOrganizations/${chain}.coc.com/orderers/orderer.${chain}.coc.com/tls/server.key"

    # Create channel using osnadmin (Fabric 3.0 channel participation API)
    echo "Creating channel $channel_name on orderer..."
    osnadmin channel join --channelID "$channel_name" \
        --config-block channel-artifacts/${channel_name}.block \
        -o localhost:$admin_port \
        --ca-file "$ORDERER_CA" \
        --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
        --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"

    # Join second orderer
    echo "Joining orderer2 to channel..."
    local admin_port2
    if [ "$chain" == "hot" ]; then
        admin_port2="7055"
        export ORDERER_ADMIN_TLS_SIGN_CERT="$chain_dir/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer2.hot.coc.com/tls/server.crt"
        export ORDERER_ADMIN_TLS_PRIVATE_KEY="$chain_dir/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer2.hot.coc.com/tls/server.key"
    else
        admin_port2="8055"
        export ORDERER_ADMIN_TLS_SIGN_CERT="$chain_dir/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer2.cold.coc.com/tls/server.crt"
        export ORDERER_ADMIN_TLS_PRIVATE_KEY="$chain_dir/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer2.cold.coc.com/tls/server.key"
    fi
    osnadmin channel join --channelID "$channel_name" \
        --config-block channel-artifacts/${channel_name}.block \
        -o localhost:$admin_port2 \
        --ca-file "$ORDERER_CA" \
        --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
        --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"

    # Join third orderer
    echo "Joining orderer3 to channel..."
    local admin_port3
    if [ "$chain" == "hot" ]; then
        admin_port3="7057"
        export ORDERER_ADMIN_TLS_SIGN_CERT="$chain_dir/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer3.hot.coc.com/tls/server.crt"
        export ORDERER_ADMIN_TLS_PRIVATE_KEY="$chain_dir/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer3.hot.coc.com/tls/server.key"
    else
        admin_port3="8057"
        export ORDERER_ADMIN_TLS_SIGN_CERT="$chain_dir/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer3.cold.coc.com/tls/server.crt"
        export ORDERER_ADMIN_TLS_PRIVATE_KEY="$chain_dir/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer3.cold.coc.com/tls/server.key"
    fi
    osnadmin channel join --channelID "$channel_name" \
        --config-block channel-artifacts/${channel_name}.block \
        -o localhost:$admin_port3 \
        --ca-file "$ORDERER_CA" \
        --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
        --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"

    print_success "Channel $channel_name created on ${chain^^} chain (all orderers joined)"
}

# Join peers to channel
join_peers() {
    local chain=$1
    local chain_dir
    local channel_name
    local orderer_address
    local cli_container

    if [ "$chain" == "hot" ]; then
        chain_dir="$HOT_DIR"
        channel_name="hotchannel"
        orderer_address="orderer.hot.coc.com:7050"
        cli_container="cli.hot"
    else
        chain_dir="$COLD_DIR"
        channel_name="coldchannel"
        orderer_address="orderer.cold.coc.com:8050"
        cli_container="cli.cold"
    fi

    print_header "Joining Peers to ${channel_name}"

    # Fetch genesis block
    echo "Fetching channel genesis block..."
    docker exec "$cli_container" peer channel fetch oldest \
        channel-artifacts/${channel_name}.block \
        -c "$channel_name" \
        -o "$orderer_address" \
        --tls \
        --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/${chain}.coc.com/orderers/orderer.${chain}.coc.com/msp/tlscacerts/tlsca.${chain}.coc.com-cert.pem

    # Join ForensicLab peer
    echo "Joining ForensicLab peer to channel..."
    docker exec "$cli_container" peer channel join -b channel-artifacts/${channel_name}.block

    # Join Court peer
    echo "Joining Court peer to channel..."
    if [ "$chain" == "hot" ]; then
        docker exec -e CORE_PEER_ADDRESS=peer0.court.hot.coc.com:7051 \
            -e CORE_PEER_LOCALMSPID=CourtMSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.hot.coc.com/peers/peer0.court.hot.coc.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.hot.coc.com/users/Admin@court.hot.coc.com/msp \
            "$cli_container" peer channel join -b channel-artifacts/${channel_name}.block
    else
        docker exec -e CORE_PEER_ADDRESS=peer0.court.cold.coc.com:9051 \
            -e CORE_PEER_LOCALMSPID=CourtMSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.cold.coc.com/peers/peer0.court.cold.coc.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.cold.coc.com/users/Admin@court.cold.coc.com/msp \
            "$cli_container" peer channel join -b channel-artifacts/${channel_name}.block
    fi

    print_success "All peers joined to $channel_name"
}

# Update anchor peers
update_anchor_peers() {
    local chain=$1
    local chain_dir
    local channel_name
    local orderer_address
    local cli_container

    if [ "$chain" == "hot" ]; then
        chain_dir="$HOT_DIR"
        channel_name="hotchannel"
        orderer_address="orderer.hot.coc.com:7050"
        cli_container="cli.hot"
    else
        chain_dir="$COLD_DIR"
        channel_name="coldchannel"
        orderer_address="orderer.cold.coc.com:8050"
        cli_container="cli.cold"
    fi

    print_header "Updating Anchor Peers for ${channel_name}"

    # Update ForensicLab anchor peer
    echo "Updating ForensicLab anchor peer..."
    docker exec "$cli_container" peer channel update \
        -o "$orderer_address" \
        -c "$channel_name" \
        -f channel-artifacts/ForensicLabMSPanchors.tx \
        --tls \
        --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/${chain}.coc.com/orderers/orderer.${chain}.coc.com/msp/tlscacerts/tlsca.${chain}.coc.com-cert.pem

    # Update Court anchor peer
    echo "Updating Court anchor peer..."
    if [ "$chain" == "hot" ]; then
        docker exec -e CORE_PEER_ADDRESS=peer0.court.hot.coc.com:7051 \
            -e CORE_PEER_LOCALMSPID=CourtMSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.hot.coc.com/peers/peer0.court.hot.coc.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.hot.coc.com/users/Admin@court.hot.coc.com/msp \
            "$cli_container" peer channel update \
            -o "$orderer_address" \
            -c "$channel_name" \
            -f channel-artifacts/CourtMSPanchors.tx \
            --tls \
            --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem
    else
        docker exec -e CORE_PEER_ADDRESS=peer0.court.cold.coc.com:9051 \
            -e CORE_PEER_LOCALMSPID=CourtMSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.cold.coc.com/peers/peer0.court.cold.coc.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.cold.coc.com/users/Admin@court.cold.coc.com/msp \
            "$cli_container" peer channel update \
            -o "$orderer_address" \
            -c "$channel_name" \
            -f channel-artifacts/CourtMSPanchors.tx \
            --tls \
            --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem
    fi

    print_success "Anchor peers updated for $channel_name"
}

# Display network status
network_status() {
    print_header "Network Status"

    echo -e "\n${BLUE}Hot Chain Containers:${NC}"
    docker ps --filter "name=hot" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No hot chain containers running"

    echo -e "\n${BLUE}Cold Chain Containers:${NC}"
    docker ps --filter "name=cold" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No cold chain containers running"
}

# Add hosts entries
add_hosts() {
    print_header "Adding /etc/hosts entries"

    echo "Please add the following entries to /etc/hosts (requires sudo):"
    echo ""
    echo "# Hot Chain"
    echo "127.0.0.1 orderer.hot.coc.com"
    echo "127.0.0.1 orderer2.hot.coc.com"
    echo "127.0.0.1 orderer3.hot.coc.com"
    echo "127.0.0.1 peer0.forensiclab.hot.coc.com"
    echo "127.0.0.1 peer0.court.hot.coc.com"
    echo ""
    echo "# Cold Chain"
    echo "127.0.0.1 orderer.cold.coc.com"
    echo "127.0.0.1 orderer2.cold.coc.com"
    echo "127.0.0.1 orderer3.cold.coc.com"
    echo "127.0.0.1 peer0.forensiclab.cold.coc.com"
    echo "127.0.0.1 peer0.court.cold.coc.com"
}

# Main script
case "$1" in
    "pull")
        pull_docker_images
        ;;
    "generate")
        if [ -z "$2" ]; then
            generate_crypto "hot"
            generate_crypto "cold"
            generate_channel_artifacts "hot"
            generate_channel_artifacts "cold"
        else
            generate_crypto "$2"
            generate_channel_artifacts "$2"
        fi
        ;;
    "start")
        if [ -z "$2" ]; then
            start_network "hot"
            start_network "cold"
        else
            start_network "$2"
        fi
        ;;
    "stop")
        if [ -z "$2" ]; then
            stop_network "hot"
            stop_network "cold"
        else
            stop_network "$2"
        fi
        ;;
    "channel")
        if [ -z "$2" ]; then
            create_channel "hot"
            create_channel "cold"
        else
            create_channel "$2"
        fi
        ;;
    "join")
        if [ -z "$2" ]; then
            join_peers "hot"
            join_peers "cold"
        else
            join_peers "$2"
        fi
        ;;
    "anchor")
        if [ -z "$2" ]; then
            update_anchor_peers "hot"
            update_anchor_peers "cold"
        else
            update_anchor_peers "$2"
        fi
        ;;
    "status")
        network_status
        ;;
    "hosts")
        add_hosts
        ;;
    "up")
        # Full setup
        pull_docker_images
        if [ -z "$2" ]; then
            generate_crypto "hot"
            generate_crypto "cold"
            generate_channel_artifacts "hot"
            generate_channel_artifacts "cold"
            start_network "hot"
            start_network "cold"
        else
            generate_crypto "$2"
            generate_channel_artifacts "$2"
            start_network "$2"
        fi
        ;;
    "down")
        if [ -z "$2" ]; then
            stop_network "hot"
            stop_network "cold"
        else
            stop_network "$2"
        fi
        ;;
    *)
        echo "Chain of Custody Blockchain Network Setup"
        echo ""
        echo "Usage: $0 <command> [chain]"
        echo ""
        echo "Commands:"
        echo "  pull          Pull required Docker images"
        echo "  generate      Generate crypto materials and channel artifacts"
        echo "  start         Start the network containers"
        echo "  stop          Stop the network containers"
        echo "  channel       Create channel"
        echo "  join          Join peers to channel"
        echo "  anchor        Update anchor peers"
        echo "  status        Show network status"
        echo "  hosts         Show /etc/hosts entries needed"
        echo "  up            Full setup (pull, generate, start)"
        echo "  down          Stop and remove containers"
        echo ""
        echo "Chain options: hot, cold (or leave empty for both)"
        echo ""
        echo "Examples:"
        echo "  $0 up              # Setup both chains"
        echo "  $0 up hot          # Setup hot chain only"
        echo "  $0 start cold      # Start cold chain"
        echo "  $0 status          # Show status of all containers"
        ;;
esac
