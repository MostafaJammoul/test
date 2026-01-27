#!/bin/bash
#
# Simple Chaincode Diagnostic
# Tests basic chaincode operations without complex JSON
#

set +e  # Don't exit on error so we can see all results

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Simple Chaincode Diagnostic${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

CASE_ID="test-001"
EVIDENCE_ID="evidence-001"
CID="QmTest123"
HASH="abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"

echo -e "${BLUE}[1/3] Creating evidence with simple metadata...${NC}"
docker exec cli.hot peer chaincode invoke \
  -o orderer.hot.coc.com:7050 \
  -C hotchannel \
  -n coc \
  --tls \
  --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem \
  -c '{"function":"CreateEvidence","Args":["'$CASE_ID'","'$EVIDENCE_ID'","'$CID'","'$HASH'","{}"]}'

echo ""
echo -e "${BLUE}[2/3] Querying evidence summary...${NC}"
docker exec cli.hot peer chaincode query \
  -C hotchannel \
  -n coc \
  -c '{"function":"GetEvidenceSummary","Args":["'$CASE_ID'","'$EVIDENCE_ID'"]}'

echo ""
echo -e "${BLUE}[3/3] Querying all evidence for case...${NC}"
docker exec cli.hot peer chaincode query \
  -C hotchannel \
  -n coc \
  -c '{"function":"QueryEvidencesByCase","Args":["'$CASE_ID'"]}'

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Diagnostic complete${NC}"
echo -e "${GREEN}========================================${NC}"
