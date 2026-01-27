#!/bin/bash
#
# Diagnostic Script: Test All Chaincode Functions
# Tests each chaincode function to verify it's accessible
#

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Chaincode Function Diagnostic${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test data
CASE_ID="diagnostic-case-001"
EVIDENCE_ID="diagnostic-evidence-001"
CID="QmTest123DiagnosticCID"
HASH="deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678"
METADATA='{"type":"diagnostic","test":true}'

echo -e "${BLUE}[1/8]${NC} Testing CreateEvidence..."
docker exec cli.hot peer chaincode invoke \
  -o orderer.hot.coc.com:7050 \
  -C hotchannel \
  -n coc \
  --tls \
  --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem \
  -c "{\"function\":\"CreateEvidence\",\"Args\":[\"$CASE_ID\",\"$EVIDENCE_ID\",\"$CID\",\"$HASH\",\"$METADATA\"]}" \
  2>&1 | grep -q "Chaincode invoke successful" && echo -e "${GREEN}✓ CreateEvidence works${NC}" || echo -e "${RED}✗ CreateEvidence failed${NC}"

echo -e "${BLUE}[2/8]${NC} Testing GetEvidenceSummary..."
docker exec cli.hot peer chaincode query \
  -C hotchannel \
  -n coc \
  -c "{\"function\":\"GetEvidenceSummary\",\"Args\":[\"$CASE_ID\",\"$EVIDENCE_ID\"]}" \
  2>&1 | grep -q "caseID" && echo -e "${GREEN}✓ GetEvidenceSummary works${NC}" || echo -e "${RED}✗ GetEvidenceSummary failed${NC}"

echo -e "${BLUE}[3/8]${NC} Testing QueryEvidencesByCase..."
docker exec cli.hot peer chaincode query \
  -C hotchannel \
  -n coc \
  -c "{\"function\":\"QueryEvidencesByCase\",\"Args\":[\"$CASE_ID\"]}" \
  2>&1 | grep -q -E "caseID|\[\]" && echo -e "${GREEN}✓ QueryEvidencesByCase works${NC}" || echo -e "${RED}✗ QueryEvidencesByCase failed${NC}"

echo -e "${BLUE}[4/8]${NC} Testing GetCustodyChain..."
docker exec cli.hot peer chaincode query \
  -C hotchannel \
  -n coc \
  -c "{\"function\":\"GetCustodyChain\",\"Args\":[\"$CASE_ID\",\"$EVIDENCE_ID\"]}" \
  2>&1 | grep -q -E "timestamp|\[\]" && echo -e "${GREEN}✓ GetCustodyChain works${NC}" || echo -e "${RED}✗ GetCustodyChain failed${NC}"

echo -e "${BLUE}[5/8]${NC} Testing GetEvidence..."
docker exec cli.hot peer chaincode query \
  -C hotchannel \
  -n coc \
  -c "{\"function\":\"GetEvidence\",\"Args\":[\"$CASE_ID\",\"$EVIDENCE_ID\"]}" \
  2>&1 | grep -q "caseID" && echo -e "${GREEN}✓ GetEvidence works${NC}" || echo -e "${RED}✗ GetEvidence failed${NC}"

echo -e "${BLUE}[6/8]${NC} Testing EvidenceExists..."
docker exec cli.hot peer chaincode query \
  -C hotchannel \
  -n coc \
  -c "{\"function\":\"EvidenceExists\",\"Args\":[\"$CASE_ID\",\"$EVIDENCE_ID\"]}" \
  2>&1 | grep -q "true" && echo -e "${GREEN}✓ EvidenceExists works${NC}" || echo -e "${RED}✗ EvidenceExists failed${NC}"

echo -e "${BLUE}[7/8]${NC} Testing TransferCustody..."
docker exec cli.hot peer chaincode invoke \
  -o orderer.hot.coc.com:7050 \
  -C hotchannel \
  -n coc \
  --tls \
  --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem \
  -c "{\"function\":\"TransferCustody\",\"Args\":[\"$CASE_ID\",\"$EVIDENCE_ID\",\"Admin@court.hot.coc.com\",\"Diagnostic test transfer\"]}" \
  2>&1 | grep -q "Chaincode invoke successful" && echo -e "${GREEN}✓ TransferCustody works${NC}" || echo -e "${RED}✗ TransferCustody failed${NC}"

echo -e "${BLUE}[8/8]${NC} Testing InvalidateEvidence..."
docker exec cli.hot peer chaincode invoke \
  -o orderer.hot.coc.com:7050 \
  -C hotchannel \
  -n coc \
  --tls \
  --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem \
  -c "{\"function\":\"InvalidateEvidence\",\"Args\":[\"$CASE_ID\",\"$EVIDENCE_ID\",\"Diagnostic test\",\"txid123\"]}" \
  2>&1 | grep -q "Chaincode invoke successful" && echo -e "${GREEN}✓ InvalidateEvidence works${NC}" || echo -e "${RED}✗ InvalidateEvidence failed${NC}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Available Chaincode Functions:${NC}"
echo -e "${BLUE}========================================${NC}"
echo "1. CreateEvidence(caseID, evidenceID, cid, hash, metadata)"
echo "2. TransferCustody(caseID, evidenceID, newCustodian, reason)"
echo "3. ArchiveToCold(caseID, evidenceID, reason)"
echo "4. ReactivateFromCold(caseID, evidenceID, reason)"
echo "5. InvalidateEvidence(caseID, evidenceID, reason, wrongTxID)"
echo "6. GetEvidenceSummary(caseID, evidenceID)"
echo "7. QueryEvidencesByCase(caseID)"
echo "8. GetCustodyChain(caseID, evidenceID)"
echo "9. GetEvidence(caseID, evidenceID)"
echo "10. EvidenceExists(caseID, evidenceID)"
echo "11. QueryEvidencesByStatus(status)"
echo ""
echo -e "${GREEN}Diagnostic complete!${NC}"
