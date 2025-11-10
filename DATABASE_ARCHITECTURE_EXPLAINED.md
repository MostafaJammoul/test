# Complete Database Architecture Explanation

**JumpServer Blockchain Chain of Custody System**
**Date**: 2025-11-09

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Database Technologies Used](#database-technologies-used)
3. [Why We Use Each Database](#why-we-use-each-database)
4. [Complete Table Structure](#complete-table-structure)
5. [Data Flow Examples](#data-flow-examples)

---

## System Overview

This system implements a **blockchain-based chain of custody** for digital evidence in law enforcement investigations. It combines **traditional relational databases** for metadata with **blockchain** for immutable audit trails and **IPFS** for decentralized file storage.

### Three-Tier Storage Architecture:

```
┌─────────────────────────────────────────────────────────┐
│                   USER INTERFACE                         │
│              (React Frontend Dashboard)                  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              POSTGRESQL DATABASE                         │
│  (User accounts, investigation metadata, relationships) │
│  • Fast queries, complex joins, search, filtering       │
│  • Mutable for operational data (tags, notes, status)   │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│          HYPERLEDGER FABRIC BLOCKCHAIN                   │
│     (Evidence hashes, transaction immutability)         │
│  • Immutable audit trail (cannot be altered/deleted)    │
│  • Cryptographic proof of evidence integrity            │
│  • Hot chain (active) + Cold chain (archived)           │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                  IPFS STORAGE                            │
│        (Large evidence files, disk images)              │
│  • Decentralized file storage (no single point failure) │
│  • Content-addressed (file hash = retrieval key)        │
│  • Efficient for multi-GB files (disk images, videos)   │
└─────────────────────────────────────────────────────────┘
```

---

## Database Technologies Used

### 1. **PostgreSQL** (Primary Relational Database)

**Location**: `/opt/truefypjs/data/db/` (SQLite in dev) or remote PostgreSQL server (production)

**What it stores**:
- User accounts and authentication
- Investigations (case metadata, status, timestamps)
- Evidence metadata (file names, sizes, IPFS CIDs, hashes)
- Blockchain transaction references (transaction hashes, block numbers)
- UI features (tags, notes, activities)
- RBAC permissions and role bindings

**Why PostgreSQL**:
- **ACID compliance** - Guarantees data consistency for user accounts and investigation metadata
- **Complex queries** - JOIN operations across investigations, evidence, users, tags
- **Full-text search** - Search investigations by case number, title, description
- **Performance** - Indexing on case_number, file_hash, IPFS CID for fast lookups
- **Mature ecosystem** - Battle-tested in production for decades
- **Django ORM support** - Native integration with Django framework

**Why NOT blockchain for this data**:
- Mutable data (users can be deactivated, tags can be renamed, investigation status changes)
- High query frequency (thousands of searches per day)
- Complex relationships (foreign keys, many-to-many joins)
- Blockchain is too slow and expensive for operational metadata

---

### 2. **Hyperledger Fabric** (Permissioned Blockchain)

**Location**: Fabric network running on dedicated nodes (configured in `config/fabric-network.json`)

**What it stores**:
- **Evidence hashes** (SHA-256 of every evidence file)
- **Merkle roots** (cryptographic tree structure for batch verification)
- **Transaction metadata** (investigation ID, user GUID, timestamp)
- **Immutable audit trail** (who uploaded what, when, and to which case)
- **Investigation notes hashes** (SHA-256 of note content for tamper detection)

**Why Hyperledger Fabric** (not Bitcoin/Ethereum):
- **Permissioned network** - Only authorized law enforcement nodes can participate
- **Privacy** - Transactions not publicly visible (unlike public blockchains)
- **No cryptocurrency** - No mining, no gas fees, no token economics
- **High throughput** - 1000+ transactions per second (vs Bitcoin's 7 TPS)
- **Finality** - Immediate confirmation (vs Bitcoin's 10-minute blocks)
- **Channel isolation** - Separate channels for different jurisdictions
- **Smart contracts** - Chaincode for evidence validation rules

**Hot Chain vs Cold Chain**:

| Feature | Hot Chain | Cold Chain |
|---------|-----------|------------|
| **Purpose** | Active investigations | Archived investigations |
| **Write frequency** | Multiple times daily | Once (at archive time) |
| **Data retention** | 2-5 years | Permanent (decades) |
| **Storage cost** | Standard SSD | Cheaper archival storage |
| **Access pattern** | Frequent reads/writes | Rare reads, no writes |
| **Validation** | Real-time merkle proofs | Batch merkle proofs |

**Why blockchain for evidence hashes**:
- **Immutability** - Once written, cannot be altered (even by system admin)
- **Tamper-evident** - Any change to evidence invalidates blockchain hash
- **Non-repudiation** - Cryptographic proof of who submitted evidence
- **Time-stamping** - Irrefutable proof of when evidence was collected
- **Chain of custody** - Complete audit trail from collection to court

---

### 3. **IPFS (InterPlanetary File System)** (Decentralized File Storage)

**Location**: IPFS nodes (configured in `config/ipfs-config.json`)

**What it stores**:
- **Large evidence files** (disk images, videos, documents, malware samples)
- **Binary content** (not metadata - that goes to PostgreSQL)

**How it works**:
1. File uploaded → IPFS calculates SHA-256 hash
2. File chunked into 256KB blocks
3. Each block stored across multiple IPFS nodes (redundancy)
4. Returns **CID** (Content Identifier): `QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG`
5. CID stored in PostgreSQL for retrieval

**Why IPFS** (not traditional file storage):
- **Content-addressed** - File retrieved by hash (not location path)
  - Traditional: `/evidence/case-001/file.exe` (location-based, can be moved/renamed)
  - IPFS: `QmYwAPJ...` (content-based, immutable identifier)
- **Deduplication** - Same file uploaded twice = same CID = no duplicate storage
- **Redundancy** - File replicated across multiple nodes (no single point of failure)
- **Integrity verification** - Download auto-verifies against CID hash
- **Censorship resistance** - No central authority can delete files
- **Bandwidth optimization** - Download from nearest node (peer-to-peer)

**Why NOT blockchain for large files**:
- **Size limits** - Blockchain blocks ~1MB, disk images are 100GB+
- **Cost** - Storing 1GB on blockchain = $millions (IPFS = pennies)
- **Performance** - Blockchain designed for small transactions, not file streaming

**IPFS Pinning**:
- Files pinned to prevent garbage collection
- Pinned files remain available indefinitely
- Unpinned files may be removed if space needed

---

### 4. **Redis** (In-Memory Cache)

**Location**: `redis://localhost:6379` (configured in `config.yml`)

**What it stores**:
- **Session data** (mTLS authentication sessions, MFA verification flags)
- **API rate limiting** (prevent abuse of blockchain APIs)
- **Temporary GUID mappings** (cache for court GUID resolutions)
- **WebSocket connections** (real-time activity notifications)

**Why Redis**:
- **Speed** - In-memory storage, sub-millisecond latency
- **Expiration** - Auto-delete old sessions (TTL: time-to-live)
- **Atomic operations** - Rate limiting counters (INCR, EXPIRE)
- **Pub/Sub** - Real-time notifications for UI activity feed

**Example Session Storage**:
```redis
SET session:3fa85f64-5717-4562-b3fc-2c963f66afa6 "{\"mtls_mfa_verified_3fa85f64\":true,\"mtls_cert_dn\":\"CN=alice\"}" EX 3600
```

**Why NOT PostgreSQL for sessions**:
- **Performance** - Redis 100x faster for simple key-value lookups
- **Scalability** - Offloads session storage from primary database
- **Built-in expiration** - Auto-cleanup of old sessions (no cron jobs)

---

## Complete Table Structure

### PostgreSQL Tables (Primary Database)

#### 1. `users_user` (JumpServer Built-in)
**Purpose**: User accounts for authentication and RBAC

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `username` | VARCHAR(128) | Unique username (e.g., "investigator_alice") |
| `name` | VARCHAR(256) | Full name (e.g., "Alice Johnson") |
| `email` | VARCHAR(256) | Email address |
| `is_active` | BOOLEAN | Account enabled/disabled |
| `mfa_level` | INTEGER | MFA requirement (0=none, 1=OTP, 2=U2F) |
| `created_at` | TIMESTAMP | Account creation timestamp |

**Why necessary**:
- Every action in the system requires a user identity
- Links to certificate, investigation, evidence, notes
- RBAC permissions applied per user

---

#### 2. `rbac_systemrolebinding` (JumpServer Built-in)
**Purpose**: Maps users to their blockchain roles

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | Foreign key → users_user |
| `role_id` | UUID | Foreign key → rbac_role (BlockchainInvestigator, etc.) |
| `scope` | VARCHAR(32) | 'system' or 'org' |
| `created_at` | TIMESTAMP | Role assignment timestamp |

**Why necessary**:
- Determines which APIs user can access
- BlockchainRoleRequiredMixin checks this table
- Prevents legacy roles from accessing blockchain features

---

#### 3. `pki_certificate`
**Purpose**: Client TLS certificates for mTLS authentication

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | Foreign key → users_user (one cert per user) |
| `subject_dn` | VARCHAR(512) | Certificate Subject DN (e.g., "CN=alice,O=Police") |
| `serial_number` | VARCHAR(64) | Certificate serial number |
| `certificate_pem` | TEXT | Full X.509 certificate in PEM format |
| `certificate_hash` | VARCHAR(64) | SHA-256 hash (prevents reissuance attacks) |
| `not_before` | TIMESTAMP | Certificate valid from |
| `not_after` | TIMESTAMP | Certificate expires at (90 days from issue) |
| `is_revoked` | BOOLEAN | Revocation status |
| `created_at` | TIMESTAMP | Issuance timestamp |

**Why necessary**:
- mTLS backend maps certificate DN → user
- Certificate hash prevents admin reissuing cert with same DN
- Expiration enforces 90-day rotation policy
- Revocation immediately blocks access (logout)

**Security**: Without this table, no certificate authentication possible.

---

#### 4. `blockchain_investigation`
**Purpose**: Investigation/case container for evidence

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `case_number` | VARCHAR(128) | Unique case number (e.g., "CASE-2025-001") |
| `title` | VARCHAR(512) | Investigation title |
| `description` | TEXT | Investigation description |
| `status` | VARCHAR(10) | 'active' or 'archived' |
| `created_by` | UUID | Foreign key → users_user (court user who created) |
| `created_at` | TIMESTAMP | Creation timestamp |
| `archived_by` | UUID | Foreign key → users_user (court user who archived) |
| `archived_at` | TIMESTAMP | Archive timestamp |
| `reopened_by` | UUID | Foreign key → users_user |
| `reopened_at` | TIMESTAMP | Reopen timestamp |
| `reopen_reason` | TEXT | Reason for reopening |

**Why necessary**:
- Every evidence file must belong to an investigation
- Status determines if evidence goes to hot chain (active) or cold chain (archived)
- Tracks who created, archived, reopened for audit trail
- case_number is searchable/filterable in UI

**Without this table**: Cannot organize evidence, no concept of "cases".

---

#### 5. `blockchain_evidence`
**Purpose**: Evidence file metadata (actual files in IPFS)

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `investigation_id` | UUID | Foreign key → blockchain_investigation |
| `title` | VARCHAR(512) | Evidence title (e.g., "Ransomware Executable") |
| `description` | TEXT | Evidence description |
| `file_name` | VARCHAR(512) | Original filename (e.g., "malware.exe") |
| `file_size` | BIGINT | File size in bytes |
| `mime_type` | VARCHAR(128) | MIME type (e.g., "application/x-executable") |
| `file_hash_sha256` | VARCHAR(64) | **CRITICAL**: SHA-256 hash of file content |
| `ipfs_cid` | VARCHAR(128) | **CRITICAL**: IPFS Content ID for retrieval |
| `encryption_key_id` | VARCHAR(256) | Encryption key ID (future: encrypted storage) |
| `uploaded_by` | UUID | Foreign key → users_user (investigator) |
| `uploaded_by_guid` | VARCHAR(256) | Anonymous GUID (if submitted anonymously) |
| `uploaded_at` | TIMESTAMP | Upload timestamp |
| `hot_chain_tx_id` | UUID | Foreign key → blockchain_transaction (hot chain record) |
| `cold_chain_tx_id` | UUID | Foreign key → blockchain_transaction (cold chain record, null if active) |
| `merkle_proof` | JSON | Merkle tree proof for verification |

**Why necessary**:
- Links file in IPFS (`ipfs_cid`) to metadata in database
- `file_hash_sha256` compared against blockchain for integrity verification
- Tracks who uploaded evidence (chain of custody)
- `hot_chain_tx_id` → proves evidence logged on blockchain
- `cold_chain_tx_id` → proves archived evidence immutably stored

**Workflow**:
1. Investigator uploads file → IPFS returns `ipfs_cid`
2. System calculates `file_hash_sha256`
3. Hash written to blockchain → returns `hot_chain_tx_id`
4. Evidence record created in this table
5. Court archives case → hash written to cold chain → `cold_chain_tx_id` updated

**Without this table**: No way to retrieve files from IPFS, no metadata, no blockchain link.

---

#### 6. `blockchain_transaction`
**Purpose**: Record of blockchain transactions (hot/cold chain)

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `investigation_id` | UUID | Foreign key → blockchain_investigation |
| `transaction_hash` | VARCHAR(256) | **CRITICAL**: Blockchain transaction hash (e.g., "0xabc123...") |
| `chain_type` | VARCHAR(4) | 'hot' or 'cold' |
| `block_number` | BIGINT | Block number in blockchain |
| `evidence_hash` | VARCHAR(256) | SHA-256 hash of evidence (must match blockchain_evidence.file_hash_sha256) |
| `ipfs_cid` | VARCHAR(128) | IPFS CID (redundant copy for quick lookup) |
| `user_id` | UUID | Foreign key → users_user |
| `user_guid` | VARCHAR(256) | Anonymous GUID (if anonymous submission) |
| `timestamp` | TIMESTAMP | Transaction timestamp |
| `merkle_root` | VARCHAR(256) | Merkle tree root hash |
| `metadata` | JSON | Additional metadata (case_number, evidence_type, etc.) |
| `verified` | BOOLEAN | Has transaction been verified on blockchain |
| `verification_date` | TIMESTAMP | Verification timestamp |

**Why necessary**:
- **Proof of blockchain logging**: Links database evidence to blockchain transaction
- **Verification**: Compare `evidence_hash` in database vs blockchain
- **Audit trail**: See when evidence was written to hot vs cold chain
- **Performance**: Avoid querying blockchain directly (expensive)

**Verification Process**:
```python
# Retrieve transaction from blockchain using transaction_hash
blockchain_tx = fabric_client.get_transaction(transaction_hash)

# Compare evidence hash
if blockchain_tx.evidence_hash == db_evidence.file_hash_sha256:
    verified = True  # Evidence NOT tampered with
else:
    verified = False  # ALERT: Evidence tampered or blockchain compromised
```

**Without this table**: No proof evidence was logged to blockchain, cannot verify integrity.

---

#### 7. `blockchain_guid_mapping`
**Purpose**: Maps anonymous GUIDs to real user identities (DNS-like service)

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `guid` | VARCHAR(256) | Anonymous GUID (encrypted, e.g., "a3d2f5e8-9b4c-4a1e-8f2d-6c7b9a0e1f3d") |
| `user_id` | UUID | Foreign key → users_user (real identity) |
| `created_at` | TIMESTAMP | Mapping creation timestamp |

**Why necessary**:
- **Anonymous submissions**: Investigators can submit evidence without revealing identity
- **Court resolution**: Only court can resolve GUID → real identity (with court order)
- **Privacy protection**: Blockchain stores GUID, not real names
- **Audit trail**: All GUID resolutions logged (who, when, why)

**Use case**:
1. Investigator Alice requests anonymous submission
2. System generates GUID: `a3d2f5e8-9b4c-4a1e-8f2d-6c7b9a0e1f3d`
3. Evidence uploaded with `user_guid` instead of `user_id`
4. Blockchain records GUID (Alice's real name NOT on blockchain)
5. Later, court issues order to reveal identity
6. Court user calls `/api/v1/blockchain/guid/resolve/`
7. System looks up GUID in this table → returns Alice's user_id

**Without this table**: No anonymous submissions, or no way to resolve anonymity.

---

#### 8. `blockchain_tag`
**Purpose**: Admin-created tag library for investigation categorization

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `name` | VARCHAR(100) | Tag name (e.g., "Cybercrime", "High Priority") |
| `category` | VARCHAR(50) | Category (crime_type, priority, status) |
| `color` | VARCHAR(7) | Hex color code (e.g., "#FF5733" for UI display) |
| `description` | TEXT | Tag description |
| `created_by` | UUID | Foreign key → users_user (admin) |
| `created_at` | TIMESTAMP | Creation timestamp |

**Why necessary**:
- **Predefined vocabulary**: Admin creates standard tags (not ad-hoc)
- **UI filtering**: Filter investigations by tag (e.g., show all "High Priority" cases)
- **Color coding**: Visual organization in dashboard
- **Categorization**: Group tags by crime_type, priority, status

**Workflow**:
1. Admin creates tag: `{"name": "Fraud", "category": "crime_type", "color": "#FFD700"}`
2. Tag appears in Court user's dropdown when assigning tags to investigation
3. Court selects 3 tags from library to assign to case

**Without this table**: Court users create arbitrary tags (no standardization, chaos).

---

#### 9. `blockchain_investigation_tag`
**Purpose**: Many-to-many relationship between investigations and tags (max 3)

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `investigation_id` | UUID | Foreign key → blockchain_investigation |
| `tag_id` | UUID | Foreign key → blockchain_tag |
| `added_by` | UUID | Foreign key → users_user (court user) |
| `added_at` | TIMESTAMP | Assignment timestamp |

**Constraints**:
- `UNIQUE (investigation_id, tag_id)` - Cannot assign same tag twice
- **Max 3 tags per investigation** - Enforced in serializer

**Why necessary**:
- **Investigation filtering**: Show all cases with "Cybercrime" tag
- **UI organization**: Display tags as colored badges on case cards
- **Audit trail**: Track who assigned which tags to which cases

**Why max 3 tags**:
- **Prevents tag spam**: Forces users to choose most relevant categories
- **UI cleanliness**: 3 badges fit nicely on investigation card
- **Cognitive load**: Too many tags = no meaningful categorization

**Without this table**: Cannot assign tags to investigations, no filtering.

---

#### 10. `blockchain_investigation_note`
**Purpose**: Investigator notes logged on blockchain

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `investigation_id` | UUID | Foreign key → blockchain_investigation |
| `content` | TEXT | Note content (e.g., "Suspect identified via IP correlation") |
| `note_hash` | VARCHAR(64) | **CRITICAL**: SHA-256 hash of content (for blockchain verification) |
| `created_by` | UUID | Foreign key → users_user (investigator) |
| `created_at` | TIMESTAMP | Note creation timestamp |
| `blockchain_tx_id` | UUID | Foreign key → blockchain_transaction (proof of blockchain logging) |

**Why necessary**:
- **Timestamped notes**: Immutable record of investigator observations
- **Blockchain verification**: `note_hash` written to blockchain, proves note NOT altered
- **Timeline reconstruction**: Show chronological investigation progress
- **Court admissibility**: Blockchain-backed notes accepted as evidence

**Workflow**:
1. Investigator writes note: "Suspect identified"
2. System calculates `note_hash = sha256("Suspect identified")`
3. Hash written to blockchain → returns `blockchain_tx_id`
4. Note saved to this table with `blockchain_tx_id` reference
5. Later verification: Recalculate hash, compare with blockchain

**Why blockchain for notes** (not just database):
- **Tamper-evident**: If note edited, hash no longer matches blockchain
- **Non-repudiation**: Proves investigator wrote note at specific time
- **Court credibility**: Blockchain-backed notes harder to challenge

**Without this table**: No investigator notes, or notes can be edited without detection.

---

#### 11. `blockchain_investigation_activity`
**Purpose**: Activity tracking for UI notifications (24-hour indicators)

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `investigation_id` | UUID | Foreign key → blockchain_investigation |
| `activity_type` | VARCHAR(20) | Type (evidence_added, note_added, tag_changed, status_changed) |
| `description` | TEXT | Human-readable description (e.g., "Evidence file 'malware.exe' was added") |
| `performed_by` | UUID | Foreign key → users_user |
| `timestamp` | TIMESTAMP | Activity timestamp |
| `viewed_by` | ManyToMany | Users who have viewed this activity |

**Why necessary**:
- **UI notifications**: Show "5 new activities in last 24 hours" badge
- **Activity feed**: Timeline of all investigation changes
- **Unread tracking**: Track which users have seen each activity
- **Audit compliance**: Full history of case changes

**Auto-created by Django signals**:
- Evidence uploaded → `evidence_added` activity
- Note created → `note_added` activity
- Tag assigned/removed → `tag_changed` activity
- Investigation archived → `status_changed` activity

**24-Hour Indicator**:
```python
@property
def is_recent(self):
    return (timezone.now() - self.timestamp).total_seconds() < 86400
```
Frontend shows red badge if `is_recent == True`

**Without this table**: No activity feed, users don't know what changed in investigation.

---

### Blockchain Storage (Hyperledger Fabric)

**Not a relational database** - Key-value store with chaincode (smart contracts)

**Data structure** (JSON stored on blockchain):
```json
{
  "transactionId": "0xabc123...",
  "investigation_id": "550e8400-e29b-41d4-a716-446655440000",
  "evidence_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "ipfs_cid": "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
  "user_guid": "a3d2f5e8-9b4c-4a1e-8f2d-6c7b9a0e1f3d",
  "merkle_root": "f7c3b1a2e8d9c4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9",
  "timestamp": "2025-11-09T13:00:00Z",
  "metadata": {
    "case_number": "CASE-2025-001",
    "evidence_type": "digital",
    "file_name": "malware.exe"
  }
}
```

**Chaincode Functions**:
- `SubmitEvidence(investigation_id, evidence_hash, ipfs_cid, user_guid)` - Write to blockchain
- `VerifyEvidence(transaction_hash, evidence_hash)` - Verify integrity
- `GetTransactionHistory(investigation_id)` - Full audit trail
- `ArchiveInvestigation(investigation_id)` - Move to cold chain

**Why blockchain over PostgreSQL for hashes**:
- **Immutability**: PostgreSQL admin can `UPDATE blockchain_transaction SET evidence_hash = 'fake'`
- **Blockchain**: Once written, cannot be altered (cryptographically impossible)
- **Trust**: Court can verify evidence integrity without trusting database admin

---

### IPFS Storage

**Not a database** - Content-addressed file storage

**Data structure**:
- Files split into 256KB chunks
- Each chunk has SHA-256 hash
- Merkle DAG (Directed Acyclic Graph) links chunks
- Root hash = Content Identifier (CID)

**Example**:
```
File: ransomware_sample.exe (2.5 MB)

Chunking:
├─ Chunk 0 (256 KB) → Hash: Qm123...
├─ Chunk 1 (256 KB) → Hash: Qm456...
├─ ...
└─ Chunk 9 (256 KB) → Hash: Qm999...

Merkle Root (CID): QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG
```

**Retrieval**:
```bash
ipfs cat QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG > ransomware_sample.exe
sha256sum ransomware_sample.exe
# Must match blockchain_evidence.file_hash_sha256
```

**Why necessary**: PostgreSQL cannot store 100GB disk images efficiently.

---

## Data Flow Examples

### Example 1: Evidence Upload

```
1. Investigator uploads malware_sample.exe (2 MB)
   ↓
2. Frontend sends file to /api/v1/blockchain/evidence/
   ↓
3. Backend uploads to IPFS
   → IPFS returns CID: QmYwAPJ...
   ↓
4. Backend calculates SHA-256: e3b0c44...
   ↓
5. Backend writes to Hyperledger Fabric hot chain
   → Blockchain returns transaction_hash: 0xabc123...
   ↓
6. Backend creates records:
   - blockchain_transaction (transaction_hash, evidence_hash, chain_type='hot')
   - blockchain_evidence (file_name, ipfs_cid, file_hash_sha256, hot_chain_tx_id)
   - blockchain_investigation_activity (activity_type='evidence_added')
   ↓
7. Frontend receives response with evidence_id, ipfs_cid, blockchain_tx_hash
```

### Example 2: Evidence Verification

```
1. Auditor clicks "Verify Evidence" button
   ↓
2. Frontend calls GET /api/v1/blockchain/evidence/{id}/verify/
   ↓
3. Backend retrieves evidence from PostgreSQL
   → file_hash_sha256 = e3b0c44...
   → hot_chain_tx_id = blockchain_transaction.id
   ↓
4. Backend queries blockchain using transaction_hash
   → blockchain_evidence_hash = e3b0c44...
   ↓
5. Backend downloads file from IPFS using ipfs_cid
   ↓
6. Backend calculates SHA-256 of downloaded file
   → calculated_hash = e3b0c44...
   ↓
7. Backend compares all three hashes:
   - PostgreSQL: e3b0c44... ✓
   - Blockchain: e3b0c44... ✓
   - IPFS file:  e3b0c44... ✓
   ↓
8. All match → Evidence VERIFIED (not tampered)
9. Any mismatch → Evidence COMPROMISED (alert admin)
```

### Example 3: Investigation Archive

```
1. Court user archives investigation CASE-2025-001
   ↓
2. Frontend calls POST /api/v1/blockchain/investigations/{id}/archive/
   ↓
3. Backend retrieves all evidence for investigation
   → Evidence IDs: [ev1, ev2, ev3, ev4, ev5]
   ↓
4. For each evidence:
   - Get evidence_hash from blockchain_evidence
   - Write to Hyperledger Fabric cold chain
   - Blockchain returns cold_chain_transaction_hash
   - Create blockchain_transaction (chain_type='cold')
   - Update blockchain_evidence.cold_chain_tx_id
   ↓
5. Update blockchain_investigation:
   - status = 'archived'
   - archived_by = current_user_id
   - archived_at = now()
   ↓
6. Create blockchain_investigation_activity:
   - activity_type = 'status_changed'
   - description = 'Investigation was archived'
   ↓
7. Frontend receives list of cold chain transaction hashes
```

---

## Summary: Why Each Database is Necessary

| Database | Primary Purpose | Cannot Be Replaced By |
|----------|----------------|----------------------|
| **PostgreSQL** | User accounts, metadata, relationships, search | Blockchain (too slow), IPFS (no query support) |
| **Hyperledger Fabric** | Immutable evidence hashes, audit trail | PostgreSQL (mutable), IPFS (no transactions) |
| **IPFS** | Large file storage, decentralized retrieval | PostgreSQL (size limits), Blockchain (cost) |
| **Redis** | Sessions, caching, real-time notifications | PostgreSQL (too slow), Files (no expiration) |

**Three databases working together**:
- PostgreSQL = "What files exist, who owns them, where to find them"
- Blockchain = "Cryptographic proof files haven't been tampered with"
- IPFS = "The actual file bytes, retrievable by content hash"

**If you removed any one**:
- No PostgreSQL → Cannot search, filter, or organize evidence
- No Blockchain → Evidence can be tampered with undetected
- No IPFS → Cannot store large files, single point of failure

---

**END OF DATABASE EXPLANATION**
