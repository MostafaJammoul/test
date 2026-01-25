#!/bin/bash

# Chaincode Testing Script for Chain of Custody Blockchain
# Tests all 8 chaincode functions on both Hot and Cold chains

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Test on a specific chain
test_chain() {
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
    else
        cli_container="cli.cold"
        channel_name="coldchannel"
        orderer_address="orderer.cold.coc.com:8050"
        orderer_ca="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem"
    fi

    print_header "Testing Chaincode on ${chain^^} Chain"

    # Test Case ID and Evidence ID
    local case_id="CASE-$(date +%s)"
    local evidence_id="EV001"

    echo -e "\nUsing Case ID: $case_id"
    echo -e "Using Evidence ID: $evidence_id\n"

    # Test 1: CreateEvidence
    echo -e "${YELLOW}Test 1: CreateEvidence${NC}"
    docker exec "$cli_container" peer chaincode invoke \
        -o "$orderer_address" \
        -C "$channel_name" \
        -n coc \
        --tls --cafile "$orderer_ca" \
        -c "{\"function\":\"CreateEvidence\",\"Args\":[\"$case_id\",\"$evidence_id\",\"QmTestCID123\",\"sha256:abc123\",\"{\\\"type\\\":\\\"disk_image\\\",\\\"size\\\":\\\"500GB\\\"}\"]}" \
        2>&1 | grep -q "Chaincode invoke successful" && print_success "CreateEvidence" || print_error "CreateEvidence"

    sleep 2

    # Test 2: GetEvidenceSummary
    echo -e "${YELLOW}Test 2: GetEvidenceSummary${NC}"
    result=$(docker exec "$cli_container" peer chaincode query \
        -C "$channel_name" \
        -n coc \
        -c "{\"function\":\"GetEvidenceSummary\",\"Args\":[\"$case_id\",\"$evidence_id\"]}" 2>&1)
    echo "$result" | grep -q "\"status\":\"ACTIVE\"" && print_success "GetEvidenceSummary" || print_error "GetEvidenceSummary"
    echo "  Response: $result"

    # Test 3: TransferCustody
    echo -e "${YELLOW}Test 3: TransferCustody${NC}"
    docker exec "$cli_container" peer chaincode invoke \
        -o "$orderer_address" \
        -C "$channel_name" \
        -n coc \
        --tls --cafile "$orderer_ca" \
        -c "{\"function\":\"TransferCustody\",\"Args\":[\"$case_id\",\"$evidence_id\",\"Analyst-Bob\",\"Transfer for analysis\"]}" \
        2>&1 | grep -q "Chaincode invoke successful" && print_success "TransferCustody" || print_error "TransferCustody"

    sleep 2

    # Test 4: GetCustodyChain
    echo -e "${YELLOW}Test 4: GetCustodyChain${NC}"
    result=$(docker exec "$cli_container" peer chaincode query \
        -C "$channel_name" \
        -n coc \
        -c "{\"function\":\"GetCustodyChain\",\"Args\":[\"$case_id\",\"$evidence_id\"]}" 2>&1)
    echo "$result" | grep -q "TRANSFER" && print_success "GetCustodyChain" || print_error "GetCustodyChain"
    echo "  Events found: $(echo "$result" | grep -o '"eventType"' | wc -l)"

    # Test 5: QueryEvidencesByCase
    echo -e "${YELLOW}Test 5: QueryEvidencesByCase${NC}"
    result=$(docker exec "$cli_container" peer chaincode query \
        -C "$channel_name" \
        -n coc \
        -c "{\"function\":\"QueryEvidencesByCase\",\"Args\":[\"$case_id\"]}" 2>&1)
    echo "$result" | grep -q "$evidence_id" && print_success "QueryEvidencesByCase" || print_error "QueryEvidencesByCase"
    echo "  Found evidence in case"

    # Test 6: ArchiveToCold
    echo -e "${YELLOW}Test 6: ArchiveToCold${NC}"
    docker exec "$cli_container" peer chaincode invoke \
        -o "$orderer_address" \
        -C "$channel_name" \
        -n coc \
        --tls --cafile "$orderer_ca" \
        -c "{\"function\":\"ArchiveToCold\",\"Args\":[\"$case_id\",\"$evidence_id\",\"Case closed - archiving\"]}" \
        2>&1 | grep -q "Chaincode invoke successful" && print_success "ArchiveToCold" || print_error "ArchiveToCold"

    sleep 2

    # Verify archived status
    result=$(docker exec "$cli_container" peer chaincode query \
        -C "$channel_name" \
        -n coc \
        -c "{\"function\":\"GetEvidenceSummary\",\"Args\":[\"$case_id\",\"$evidence_id\"]}" 2>&1)
    echo "$result" | grep -q "\"status\":\"ARCHIVED\"" && echo "  Status verified: ARCHIVED" || echo "  Status check failed"

    # Test 7: ReactivateFromCold
    echo -e "${YELLOW}Test 7: ReactivateFromCold${NC}"
    docker exec "$cli_container" peer chaincode invoke \
        -o "$orderer_address" \
        -C "$channel_name" \
        -n coc \
        --tls --cafile "$orderer_ca" \
        -c "{\"function\":\"ReactivateFromCold\",\"Args\":[\"$case_id\",\"$evidence_id\",\"Appeal filed - reactivating\"]}" \
        2>&1 | grep -q "Chaincode invoke successful" && print_success "ReactivateFromCold" || print_error "ReactivateFromCold"

    sleep 2

    # Verify reactivated status
    result=$(docker exec "$cli_container" peer chaincode query \
        -C "$channel_name" \
        -n coc \
        -c "{\"function\":\"GetEvidenceSummary\",\"Args\":[\"$case_id\",\"$evidence_id\"]}" 2>&1)
    echo "$result" | grep -q "\"status\":\"REACTIVATED\"" && echo "  Status verified: REACTIVATED" || echo "  Status check failed"

    # Test 8: InvalidateEvidence
    echo -e "${YELLOW}Test 8: InvalidateEvidence${NC}"
    docker exec "$cli_container" peer chaincode invoke \
        -o "$orderer_address" \
        -C "$channel_name" \
        -n coc \
        --tls --cafile "$orderer_ca" \
        -c "{\"function\":\"InvalidateEvidence\",\"Args\":[\"$case_id\",\"$evidence_id\",\"Evidence tampered\",\"tx123\"]}" \
        2>&1 | grep -q "Chaincode invoke successful" && print_success "InvalidateEvidence" || print_error "InvalidateEvidence"

    sleep 2

    # Verify invalidated status
    result=$(docker exec "$cli_container" peer chaincode query \
        -C "$channel_name" \
        -n coc \
        -c "{\"function\":\"GetEvidenceSummary\",\"Args\":[\"$case_id\",\"$evidence_id\"]}" 2>&1)
    echo "$result" | grep -q "\"status\":\"INVALIDATED\"" && echo "  Status verified: INVALIDATED" || echo "  Status check failed"

    # Final custody chain
    echo -e "\n${YELLOW}Final Custody Chain:${NC}"
    docker exec "$cli_container" peer chaincode query \
        -C "$channel_name" \
        -n coc \
        -c "{\"function\":\"GetCustodyChain\",\"Args\":[\"$case_id\",\"$evidence_id\"]}" 2>&1 | python3 -m json.tool 2>/dev/null || echo "Raw output received"

    print_header "Testing Complete for ${chain^^} Chain"
}

# Main
case "$1" in
    "hot")
        test_chain "hot"
        ;;
    "cold")
        test_chain "cold"
        ;;
    "both"|"")
        test_chain "hot"
        test_chain "cold"
        ;;
    *)
        echo "Usage: $0 [hot|cold|both]"
        exit 1
        ;;
esac
