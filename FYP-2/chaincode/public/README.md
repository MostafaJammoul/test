# Public Chaincode - Evidence Custody Operations

This chaincode implements the public custody operations for the DFIR blockchain system. It handles evidence registration, custody transfers, archival, and invalidation.

## Functions

### CreateEvidence
Creates a new evidence record on the blockchain.

**Arguments:**
- `caseID` (string): Unique case identifier
- `evidenceID` (string): Unique evidence identifier within the case
- `cid` (string): IPFS Content Identifier for the evidence file
- `hash` (string): SHA-256 hash of the evidence file (64 hex characters)
- `metadata` (string): JSON metadata about the evidence

**Returns:** Evidence object (JSON)

**Example:**
```bash
peer chaincode invoke -C evidence-hot -n custody \
  -c '{"Args":["CreateEvidence","CASE001","EVD001","QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG","a3b2c1d4e5f6...","{"type":"disk-image","size":104857600}"]}'
```

### TransferCustody
Transfers custody of evidence to a new custodian.

**Arguments:**
- `caseID` (string): Case identifier
- `evidenceID` (string): Evidence identifier
- `newCustodian` (string): Identity of new custodian
- `transferReason` (string): Reason for transfer

**Returns:** Updated evidence object (JSON)

**Preconditions:** Evidence must be in ACTIVE or REACTIVATED status

### ArchiveToCold
Archives evidence from hot chain to cold chain.

**Arguments:**
- `caseID` (string): Case identifier
- `evidenceID` (string): Evidence identifier
- `archiveReason` (string): Reason for archival

**Returns:** Updated evidence object (JSON)

**Preconditions:** Evidence must be in ACTIVE status

**Note:** This function is called on the hot chain. The evidence state is updated to ARCHIVED.

### ReactivateFromCold
Reactivates archived evidence back to active status.

**Arguments:**
- `caseID` (string): Case identifier
- `evidenceID` (string): Evidence identifier
- `reactivationReason` (string): Reason for reactivation

**Returns:** Updated evidence object (JSON)

**Preconditions:** Evidence must be in ARCHIVED status

### InvalidateEvidence
Marks evidence as invalidated due to tampering or procedural errors.

**Arguments:**
- `caseID` (string): Case identifier
- `evidenceID` (string): Evidence identifier
- `reason` (string): Reason for invalidation
- `wrongTxID` (string): Transaction ID of the problematic transaction

**Returns:** Updated evidence object (JSON)

**Note:** This is an irreversible operation. Once invalidated, evidence cannot be reactivated.

### GetEvidenceSummary
Retrieves the complete evidence record.

**Arguments:**
- `caseID` (string): Case identifier
- `evidenceID` (string): Evidence identifier

**Returns:** Complete evidence object (JSON)

### QueryEvidencesByCase
Retrieves all evidence items for a specific case.

**Arguments:**
- `caseID` (string): Case identifier

**Returns:** Array of evidence objects (JSON)

### GetCustodyChain
Retrieves the complete custody chain (all events) for a piece of evidence.

**Arguments:**
- `caseID` (string): Case identifier
- `evidenceID` (string): Evidence identifier

**Returns:** Array of custody events (JSON)

## Data Structures

### Evidence
```json
{
  "caseId": "CASE001",
  "evidenceId": "EVD001",
  "cid": "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
  "hash": "a3b2c1d4e5f6789012345678901234567890123456789012345678901234abcd",
  "metadata": "{\"type\":\"disk-image\",\"size\":104857600}",
  "status": "ACTIVE",
  "events": [...],
  "createdAt": "2026-01-18T12:00:00Z",
  "updatedAt": "2026-01-18T14:30:00Z",
  "currentOwner": "CN=investigator1,OU=forensiclab",
  "ownerOrgMSP": "ForensicLabMSP"
}
```

### CustodyEvent
```json
{
  "timestamp": "2026-01-18T12:00:00Z",
  "eventType": "CREATE",
  "actor": "CN=investigator1,OU=forensiclab",
  "orgMSP": "ForensicLabMSP",
  "description": "Evidence created and registered",
  "txId": "a1b2c3d4e5f6..."
}
```

### Evidence Status Values
- `ACTIVE`: Evidence is actively being used in an investigation
- `ARCHIVED`: Evidence has been archived to cold chain
- `REACTIVATED`: Previously archived evidence that has been reactivated
- `INVALIDATED`: Evidence has been invalidated (e.g., chain of custody broken)

## World State Key Design

Evidence is stored using composite keys: `caseID:evidenceID`

This allows efficient queries by case ID using partial composite key queries.

## Access Control

Access control is enforced at two levels:

1. **Chaincode level**: This chaincode performs basic validation
2. **Endorsement policies**: Network-level policies require approval from both ForensicLabMSP and CourtMSP for sensitive operations

### Recommended Endorsement Policies

- **CreateEvidence**: `OR('ForensicLabMSP.member', 'CourtMSP.member')`
- **TransferCustody**: `OR('ForensicLabMSP.member', 'CourtMSP.member')`
- **ArchiveToCold**: `AND('ForensicLabMSP.member', 'CourtMSP.member')`
- **ReactivateFromCold**: `AND('ForensicLabMSP.member', 'CourtMSP.member')`
- **InvalidateEvidence**: `AND('ForensicLabMSP.admin', 'CourtMSP.admin')`

## Events

The chaincode emits the following events:

- `EvidenceCreated`: When new evidence is registered
- `CustodyTransferred`: When custody is transferred
- `EvidenceArchived`: When evidence is archived to cold chain
- `EvidenceReactivated`: When archived evidence is reactivated
- `EvidenceInvalidated`: When evidence is invalidated

## Building and Deploying

### Build
```bash
cd chaincode/public
go mod tidy
go mod vendor
peer lifecycle chaincode package custody.tar.gz --path . --lang golang --label custody_1.0
```

### Install
```bash
# On ForensicLabMSP peer
peer lifecycle chaincode install custody.tar.gz

# On CourtMSP peer
peer lifecycle chaincode install custody.tar.gz
```

### Approve and Commit
```bash
# Get package ID
peer lifecycle chaincode queryinstalled

# Approve (both organizations)
peer lifecycle chaincode approveformyorg \
  -o orderer.hot.dfir.local:7050 \
  --channelID evidence-hot \
  --name custody \
  --version 1.0 \
  --package-id <PACKAGE_ID> \
  --sequence 1 \
  --tls \
  --cafile <ORDERER_CA>

# Commit
peer lifecycle chaincode commit \
  -o orderer.hot.dfir.local:7050 \
  --channelID evidence-hot \
  --name custody \
  --version 1.0 \
  --sequence 1 \
  --tls \
  --cafile <ORDERER_CA> \
  --peerAddresses peer0.lab.hot.dfir.local:7051 \
  --tlsRootCertFiles <LAB_TLS_CA> \
  --peerAddresses peer0.court.hot.dfir.local:8051 \
  --tlsRootCertFiles <COURT_TLS_CA>
```

## Security Considerations

1. **Hash Validation**: The chaincode validates that hashes are proper SHA-256 (64 hex characters)
2. **Immutability**: Once evidence is created, its CID and hash cannot be modified
3. **Audit Trail**: All custody events are permanently recorded with timestamps and actor identities
4. **Status Transitions**: Only valid state transitions are allowed (e.g., can't archive already archived evidence)
5. **Endorsement**: Critical operations require multi-org endorsement

## Compliance

This chaincode supports compliance with:
- **ISO 23257:2022**: Blockchain and DLT technologies
- **ISO/IEC 27037:2012**: Guidelines for digital evidence identification and collection
- **Lebanese Law No. 81/2018**: Electronic transactions and personal data
- **U.S. Federal Rules of Evidence 901/902**: Authentication and self-authentication

## Testing

Unit tests are located in `chaincode_test.go`. Run tests with:
```bash
go test -v
```

## Integration with IPFS

Evidence files are stored in the private IPFS cluster. The CID stored in the chaincode references the IPFS content. To verify integrity:

1. Retrieve file from IPFS using CID
2. Compute SHA-256 hash of retrieved file
3. Compare with hash stored on blockchain
4. If hashes match, file integrity is verified

## License

See project LICENSE file.
