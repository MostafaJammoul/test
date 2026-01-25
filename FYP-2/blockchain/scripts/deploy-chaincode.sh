#!/bin/bash

# Chaincode Deployment Script for Chain of Custody Blockchain
# Deploys the CoC chaincode to both Hot and Cold chains

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCKCHAIN_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$BLOCKCHAIN_DIR/bin"
HOT_DIR="$BLOCKCHAIN_DIR/hot-chain"
COLD_DIR="$BLOCKCHAIN_DIR/cold-chain"
CHAINCODE_DIR="$BLOCKCHAIN_DIR/chaincode/coc"

export PATH="$BIN_DIR:$PATH"
export FABRIC_CFG_PATH="$HOT_DIR/config/peercfg"

# Chaincode settings
CC_NAME="coc"
CC_VERSION="1.0"
CC_SEQUENCE="1"
CC_PACKAGE_ID=""

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Package chaincode
package_chaincode() {
    print_header "Packaging Chaincode"

    cd "$BLOCKCHAIN_DIR"

    # Verify chaincode files exist
    if [ ! -f "$CHAINCODE_DIR/chaincode.go" ]; then
        print_error "Chaincode source not found at $CHAINCODE_DIR"
        exit 1
    fi

    if [ ! -f "$CHAINCODE_DIR/go.mod" ]; then
        print_error "go.mod not found at $CHAINCODE_DIR"
        exit 1
    fi

    echo "Chaincode source verified..."

    # Create package using peer CLI
    peer lifecycle chaincode package ${CC_NAME}.tar.gz \
        --path "$CHAINCODE_DIR" \
        --lang golang \
        --label ${CC_NAME}_${CC_VERSION}

    if [ -f "${CC_NAME}.tar.gz" ]; then
        print_success "Chaincode packaged as ${CC_NAME}.tar.gz"
    else
        print_error "Failed to create chaincode package"
        exit 1
    fi
}

# Install chaincode on a peer
install_chaincode() {
    local chain=$1
    local org=$2
    local cli_container
    local peer_address
    local msp_id
    local tls_rootcert

    if [ "$chain" == "hot" ]; then
        cli_container="cli.hot"
        if [ "$org" == "forensiclab" ]; then
            peer_address="peer0.forensiclab.hot.coc.com:8051"
            msp_id="ForensicLabMSP"
            tls_rootcert="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt"
            msp_path="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp"
        else
            peer_address="peer0.court.hot.coc.com:7051"
            msp_id="CourtMSP"
            tls_rootcert="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.hot.coc.com/peers/peer0.court.hot.coc.com/tls/ca.crt"
            msp_path="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.hot.coc.com/users/Admin@court.hot.coc.com/msp"
        fi
    else
        cli_container="cli.cold"
        if [ "$org" == "forensiclab" ]; then
            peer_address="peer0.forensiclab.cold.coc.com:10051"
            msp_id="ForensicLabMSP"
            tls_rootcert="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.cold.coc.com/peers/peer0.forensiclab.cold.coc.com/tls/ca.crt"
            msp_path="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.cold.coc.com/users/Admin@forensiclab.cold.coc.com/msp"
        else
            peer_address="peer0.court.cold.coc.com:9051"
            msp_id="CourtMSP"
            tls_rootcert="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.cold.coc.com/peers/peer0.court.cold.coc.com/tls/ca.crt"
            msp_path="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.cold.coc.com/users/Admin@court.cold.coc.com/msp"
        fi
    fi

    print_header "Installing Chaincode on $org peer (${chain^^} chain)"

    # Copy chaincode package to CLI container
    docker cp "$BLOCKCHAIN_DIR/${CC_NAME}.tar.gz" "${cli_container}:/opt/gopath/src/github.com/hyperledger/fabric/peer/"

    # Install chaincode
    docker exec \
        -e CORE_PEER_ADDRESS="$peer_address" \
        -e CORE_PEER_LOCALMSPID="$msp_id" \
        -e CORE_PEER_TLS_ROOTCERT_FILE="$tls_rootcert" \
        -e CORE_PEER_MSPCONFIGPATH="$msp_path" \
        "$cli_container" \
        peer lifecycle chaincode install ${CC_NAME}.tar.gz

    print_success "Chaincode installed on $org peer (${chain^^} chain)"
}

# Get installed chaincode package ID
get_package_id() {
    local chain=$1
    local cli_container

    if [ "$chain" == "hot" ]; then
        cli_container="cli.hot"
    else
        cli_container="cli.cold"
    fi

    CC_PACKAGE_ID=$(docker exec "$cli_container" peer lifecycle chaincode queryinstalled | grep "${CC_NAME}_${CC_VERSION}" | awk -F "Package ID: " '{print $2}' | awk -F "," '{print $1}')

    echo "Package ID: $CC_PACKAGE_ID"
}

# Approve chaincode for org
approve_chaincode() {
    local chain=$1
    local org=$2
    local cli_container
    local peer_address
    local msp_id
    local tls_rootcert
    local orderer_address
    local orderer_ca
    local channel_name

    if [ "$chain" == "hot" ]; then
        cli_container="cli.hot"
        channel_name="hotchannel"
        orderer_address="orderer.hot.coc.com:7050"
        orderer_ca="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem"

        if [ "$org" == "forensiclab" ]; then
            peer_address="peer0.forensiclab.hot.coc.com:8051"
            msp_id="ForensicLabMSP"
            tls_rootcert="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt"
            msp_path="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp"
        else
            peer_address="peer0.court.hot.coc.com:7051"
            msp_id="CourtMSP"
            tls_rootcert="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.hot.coc.com/peers/peer0.court.hot.coc.com/tls/ca.crt"
            msp_path="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.hot.coc.com/users/Admin@court.hot.coc.com/msp"
        fi
    else
        cli_container="cli.cold"
        channel_name="coldchannel"
        orderer_address="orderer.cold.coc.com:8050"
        orderer_ca="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem"

        if [ "$org" == "forensiclab" ]; then
            peer_address="peer0.forensiclab.cold.coc.com:10051"
            msp_id="ForensicLabMSP"
            tls_rootcert="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.cold.coc.com/peers/peer0.forensiclab.cold.coc.com/tls/ca.crt"
            msp_path="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.cold.coc.com/users/Admin@forensiclab.cold.coc.com/msp"
        else
            peer_address="peer0.court.cold.coc.com:9051"
            msp_id="CourtMSP"
            tls_rootcert="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.cold.coc.com/peers/peer0.court.cold.coc.com/tls/ca.crt"
            msp_path="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.cold.coc.com/users/Admin@court.cold.coc.com/msp"
        fi
    fi

    print_header "Approving Chaincode for $org (${chain^^} chain)"

    docker exec \
        -e CORE_PEER_ADDRESS="$peer_address" \
        -e CORE_PEER_LOCALMSPID="$msp_id" \
        -e CORE_PEER_TLS_ROOTCERT_FILE="$tls_rootcert" \
        -e CORE_PEER_MSPCONFIGPATH="$msp_path" \
        "$cli_container" \
        peer lifecycle chaincode approveformyorg \
        -o "$orderer_address" \
        --channelID "$channel_name" \
        --name "$CC_NAME" \
        --version "$CC_VERSION" \
        --package-id "$CC_PACKAGE_ID" \
        --sequence "$CC_SEQUENCE" \
        --tls \
        --cafile "$orderer_ca"

    print_success "Chaincode approved by $org (${chain^^} chain)"
}

# Check commit readiness
check_commit_readiness() {
    local chain=$1
    local cli_container
    local channel_name

    if [ "$chain" == "hot" ]; then
        cli_container="cli.hot"
        channel_name="hotchannel"
    else
        cli_container="cli.cold"
        channel_name="coldchannel"
    fi

    print_header "Checking Commit Readiness (${chain^^} chain)"

    docker exec "$cli_container" \
        peer lifecycle chaincode checkcommitreadiness \
        --channelID "$channel_name" \
        --name "$CC_NAME" \
        --version "$CC_VERSION" \
        --sequence "$CC_SEQUENCE" \
        --output json
}

# Commit chaincode
commit_chaincode() {
    local chain=$1
    local cli_container
    local channel_name
    local orderer_address
    local orderer_ca

    if [ "$chain" == "hot" ]; then
        cli_container="cli.hot"
        channel_name="hotchannel"
        orderer_address="orderer.hot.coc.com:7050"
        orderer_ca="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem"

        peer_forensiclab="peer0.forensiclab.hot.coc.com:8051"
        tls_forensiclab="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt"

        # Hot chain: Only ForensicLabMSP endorsement required (CourtMSP is read-only participant)
        print_header "Committing Chaincode (${chain^^} chain - ForensicLabMSP endorsement only)"

        docker exec "$cli_container" \
            peer lifecycle chaincode commit \
            -o "$orderer_address" \
            --channelID "$channel_name" \
            --name "$CC_NAME" \
            --version "$CC_VERSION" \
            --sequence "$CC_SEQUENCE" \
            --tls \
            --cafile "$orderer_ca" \
            --peerAddresses "$peer_forensiclab" \
            --tlsRootCertFiles "$tls_forensiclab"
    else
        cli_container="cli.cold"
        channel_name="coldchannel"
        orderer_address="orderer.cold.coc.com:8050"
        orderer_ca="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem"

        peer_forensiclab="peer0.forensiclab.cold.coc.com:10051"
        peer_court="peer0.court.cold.coc.com:9051"
        tls_forensiclab="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.cold.coc.com/peers/peer0.forensiclab.cold.coc.com/tls/ca.crt"
        tls_court="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.cold.coc.com/peers/peer0.court.cold.coc.com/tls/ca.crt"

        # Cold chain: Both ForensicLabMSP and CourtMSP endorsement required
        print_header "Committing Chaincode (${chain^^} chain)"

        docker exec "$cli_container" \
            peer lifecycle chaincode commit \
            -o "$orderer_address" \
            --channelID "$channel_name" \
            --name "$CC_NAME" \
            --version "$CC_VERSION" \
            --sequence "$CC_SEQUENCE" \
            --tls \
            --cafile "$orderer_ca" \
            --peerAddresses "$peer_forensiclab" \
            --tlsRootCertFiles "$tls_forensiclab" \
            --peerAddresses "$peer_court" \
            --tlsRootCertFiles "$tls_court"
    fi

    print_success "Chaincode committed on ${chain^^} chain"
}

# Query committed chaincode
query_committed() {
    local chain=$1
    local cli_container
    local channel_name

    if [ "$chain" == "hot" ]; then
        cli_container="cli.hot"
        channel_name="hotchannel"
    else
        cli_container="cli.cold"
        channel_name="coldchannel"
    fi

    print_header "Querying Committed Chaincode (${chain^^} chain)"

    docker exec "$cli_container" \
        peer lifecycle chaincode querycommitted \
        --channelID "$channel_name" \
        --name "$CC_NAME"
}

# Full deployment to a chain
deploy_to_chain() {
    local chain=$1

    echo "Deploying chaincode to ${chain^^} chain..."

    # Install on both peers
    install_chaincode "$chain" "forensiclab"
    install_chaincode "$chain" "court"

    # Get package ID
    get_package_id "$chain"

    # Approve for both orgs
    approve_chaincode "$chain" "forensiclab"
    approve_chaincode "$chain" "court"

    # Check readiness
    check_commit_readiness "$chain"

    # Commit
    commit_chaincode "$chain"

    # Verify
    query_committed "$chain"

    print_success "Chaincode deployed to ${chain^^} chain"
}

# Main script
case "$1" in
    "package")
        package_chaincode
        ;;
    "install")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 install <chain> <org>"
            echo "  chain: hot or cold"
            echo "  org: forensiclab or court"
            exit 1
        fi
        install_chaincode "$2" "$3"
        ;;
    "approve")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 approve <chain> <org>"
            exit 1
        fi
        get_package_id "$2"
        approve_chaincode "$2" "$3"
        ;;
    "commit")
        if [ -z "$2" ]; then
            echo "Usage: $0 commit <chain>"
            exit 1
        fi
        commit_chaincode "$2"
        ;;
    "query")
        if [ -z "$2" ]; then
            echo "Usage: $0 query <chain>"
            exit 1
        fi
        query_committed "$2"
        ;;
    "deploy")
        package_chaincode
        if [ -z "$2" ]; then
            deploy_to_chain "hot"
            deploy_to_chain "cold"
        else
            deploy_to_chain "$2"
        fi
        ;;
    *)
        echo "Chaincode Deployment Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  package              Package the chaincode"
        echo "  install <chain> <org>  Install on a specific peer"
        echo "  approve <chain> <org>  Approve for an organization"
        echo "  commit <chain>       Commit chaincode definition"
        echo "  query <chain>        Query committed chaincode"
        echo "  deploy [chain]       Full deployment (package, install, approve, commit)"
        echo ""
        echo "Options:"
        echo "  chain: hot, cold (or leave empty for both)"
        echo "  org: forensiclab, court"
        echo ""
        echo "Examples:"
        echo "  $0 deploy            # Deploy to both chains"
        echo "  $0 deploy hot        # Deploy to hot chain only"
        echo "  $0 install hot forensiclab"
        ;;
esac
