# API Bridge to Chaincode Function Mapping

## Overview
This document maps API bridge endpoints to their corresponding chaincode functions.

---

## ✅ Verified Mappings (CORRECT)

### 1. Create Evidence
- **API Endpoint**: `POST /api/evidence`
- **API Bridge Call**: `hotContract.submitTransaction('CreateEvidence', caseID, evidenceID, cid, hash, metadataStr)`
- **Chaincode Function**: `CreateEvidence(ctx, caseID, evidenceID, cid, hash, metadata)`
- **Status**: ✅ CORRECT

### 2. Query Evidence Summary
- **API Endpoint**: `GET /api/evidence/:evidenceID?caseID=xxx`
- **API Bridge Call**: `hotContract.evaluateTransaction('GetEvidenceSummary', caseID, evidenceID)`
- **Chaincode Function**: `GetEvidenceSummary(ctx, caseID, evidenceID)`
- **Status**: ✅ CORRECT (Fixed)

### 3. Query Evidence by Case
- **API Endpoint**: `GET /api/evidence/case/:caseID`
- **API Bridge Call**: `hotContract.evaluateTransaction('QueryEvidencesByCase', caseID)`
- **Chaincode Function**: `QueryEvidencesByCase(ctx, caseID)`
- **Status**: ✅ CORRECT (Fixed)

### 4. Transfer Custody
- **API Endpoint**: `POST /api/evidence/:evidenceID/transfer`
- **API Bridge Call**: `hotContract.submitTransaction('TransferCustody', caseID, evidenceID, newOwner, reason)`
- **Chaincode Function**: `TransferCustody(ctx, caseID, evidenceID, newCustodian, transferReason)`
- **Status**: ✅ CORRECT

### 5. Archive to Cold Chain
- **API Endpoint**: `POST /api/evidence/:evidenceID/archive`
- **API Bridge Call**: `hotContract.submitTransaction('ArchiveToCold', caseID, evidenceID)`
- **Chaincode Function**: `ArchiveToCold(ctx, caseID, evidenceID, archiveReason)`
- **Status**: ⚠️ MISSING PARAMETER - archiveReason

---

## 📋 All Available Chaincode Functions

### Write Operations (submitTransaction)
1. `CreateEvidence(caseID, evidenceID, cid, hash, metadata)` - Create new evidence
2. `TransferCustody(caseID, evidenceID, newCustodian, transferReason)` - Transfer custody
3. `ArchiveToCold(caseID, evidenceID, archiveReason)` - Archive to cold chain
4. `ReactivateFromCold(caseID, evidenceID, reactivationReason)` - Reactivate from cold
5. `InvalidateEvidence(caseID, evidenceID, reason, wrongTxID)` - Mark as invalid

### Read Operations (evaluateTransaction)
6. `GetEvidenceSummary(caseID, evidenceID)` - Get evidence summary
7. `QueryEvidencesByCase(caseID)` - Get all evidence for a case
8. `GetCustodyChain(caseID, evidenceID)` - Get custody history
9. `GetEvidence(caseID, evidenceID)` - Get full evidence details
10. `EvidenceExists(caseID, evidenceID)` - Check if evidence exists
11. `QueryEvidencesByStatus(status)` - Query by status (ACTIVE, ARCHIVED, etc.)

---

## 🔧 API Bridge Endpoints

### Implemented
- ✅ `POST /api/evidence` → CreateEvidence
- ✅ `GET /api/evidence/:evidenceID?caseID=xxx` → GetEvidenceSummary
- ✅ `GET /api/evidence/case/:caseID` → QueryEvidencesByCase
- ✅ `POST /api/evidence/:evidenceID/transfer` → TransferCustody
- ⚠️ `POST /api/evidence/:evidenceID/archive` → ArchiveToCold (missing reason param)

### Not Implemented (Available for Future Use)
- ❌ `POST /api/evidence/:evidenceID/reactivate` → ReactivateFromCold
- ❌ `POST /api/evidence/:evidenceID/invalidate` → InvalidateEvidence
- ❌ `GET /api/evidence/:evidenceID/custody?caseID=xxx` → GetCustodyChain
- ❌ `GET /api/evidence/:evidenceID/full?caseID=xxx` → GetEvidence
- ❌ `GET /api/evidence/:evidenceID/exists?caseID=xxx` → EvidenceExists
- ❌ `GET /api/evidence/status/:status` → QueryEvidencesByStatus

---

## 🐛 Issues Fixed

### Issue 1: Wrong Function Name
- **Problem**: API called `QueryByCase` but chaincode has `QueryEvidencesByCase`
- **Fix**: Changed to `QueryEvidencesByCase` in server.js line 320
- **Commit**: cd47100d

### Issue 2: Missing caseID Parameter
- **Problem**: Query endpoint didn't require caseID (composite key needed)
- **Fix**: Added caseID as required query parameter
- **Commit**: 22fe9da6

### Issue 3: Uint8Array Decoding
- **Problem**: resultBytes.toString() produced comma-separated bytes
- **Fix**: Use Buffer.from(resultBytes).toString('utf8')
- **Commit**: cd47100d

---

## 🧪 Testing

### Run Diagnostic Script
```bash
cd ~/Desktop/FYP-2
./test-chaincode-functions.sh
```

This will test all 8 core chaincode functions and verify they're accessible.

### Run Integration Tests
```bash
# On VM 1
cd /home/jsroot/js/apps
./test_integration.sh
```

---

## 📝 Notes

1. All chaincode functions require `caseID` and `evidenceID` parameters due to composite key structure
2. The API bridge currently only implements 5 out of 11 available chaincode functions
3. IPFS integration is optional - will use mock CIDs if IPFS is unavailable
4. Both hot and cold chains use the same chaincode but different channels
5. Cold chain operations (archive/reactivate) should use coldContract instead of hotContract

---

## 🔄 Update History

- 2026-01-27: Fixed QueryByCase → QueryEvidencesByCase
- 2026-01-27: Fixed Uint8Array decoding issue
- 2026-01-27: Added caseID parameter requirement
- 2026-01-27: Fixed channel names (hotchannel/coldchannel)
