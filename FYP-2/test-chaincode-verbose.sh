#!/bin/bash
#
# Verbose Chaincode Diagnostic
# Shows actual output from chaincode calls
#

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Verbose Chaincode Diagnostic${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test data
CASE_ID="diagnostic-case-001"
EVIDENCE_ID="diagnostic-evidence-001"
CID="QmTest123DiagnosticCID"
HASH="deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678"
# Escape quotes in metadata for proper JSON nesting
METADATA='{\"type\":\"diagnostic\",\"test\":true}'

echo -e "${BLUE}[1/3] Testing CreateEvidence (invoke)...${NC}"
docker exec cli.hot peer chaincode invoke \
  -o orderer.hot.coc.com:7050 \
  -C hotchannel \
  -n coc \
  --tls \
  --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem \
  -c '{"function":"CreateEvidence","Args":["'"$CASE_ID"'","'"$EVIDENCE_ID"'","'"$CID"'","'"$HASH"'","{\\\"type\\\":\\\"diagnostic\\\",\\\"test\\\":true}"]}'

echo ""
echo -e "${BLUE}[2/3] Testing GetEvidenceSummary (query)...${NC}"
docker exec cli.hot peer chaincode query \
  -C hotchannel \
  -n coc \
  -c "{\"function\":\"GetEvidenceSummary\",\"Args\":[\"$CASE_ID\",\"$EVIDENCE_ID\"]}"

echo ""
echo -e "${BLUE}[3/3] Testing QueryEvidencesByCase (query)...${NC}"
docker exec cli.hot peer chaincode query \
  -C hotchannel \
  -n coc \
  -c "{\"function\":\"QueryEvidencesByCase\",\"Args\":[\"$CASE_ID\"]}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Diagnostic complete - check output above${NC}"
echo -e "${GREEN}========================================${NC}"
