# Blockchain Chain of Custody API Documentation

**Version**: 1.0
**Date**: 2025-11-09
**Base URL**: `https://jumpserver.example.com/api/v1/blockchain/`

---

## Table of Contents

1. [Authentication](#authentication)
2. [Core Blockchain APIs](#core-blockchain-apis)
   - [Investigations](#investigations)
   - [Evidence](#evidence)
   - [Blockchain Transactions](#blockchain-transactions)
   - [GUID Resolution](#guid-resolution)
3. [UI Enhancement APIs](#ui-enhancement-apis)
   - [Tags](#tags)
   - [Investigation Tags](#investigation-tags)
   - [Investigation Notes](#investigation-notes)
   - [Investigation Activities](#investigation-activities)
4. [Role-Based Access Control](#role-based-access-control)
5. [Error Responses](#error-responses)

---

## Authentication

All API endpoints require **mTLS (Mutual TLS) authentication** with **MFA (Multi-Factor Authentication)**.

### Authentication Flow:
1. **Client Certificate**: Browser presents user certificate (issued by admin)
2. **Certificate Validation**: nginx verifies certificate against Internal CA
3. **MFA Challenge**: User enters TOTP code from authenticator app
4. **Session Token**: Authenticated session established

### Headers:
```http
X-SSL-Client-DN: CN=alice,O=Police,C=US
X-SSL-Client-Verify: SUCCESS
Authorization: Session <session_token>
```

---

## Core Blockchain APIs

### Investigations

**Base Path**: `/api/v1/blockchain/investigations/`

#### List Investigations
```http
GET /api/v1/blockchain/investigations/
```

**Query Parameters**:
- `status` (string): Filter by status (`active`, `archived`)
- `created_by` (UUID): Filter by creator user ID
- `search` (string): Search in case number, title, description
- `ordering` (string): Order by field (e.g., `-created_at`, `case_number`)

**Response** (200 OK):
```json
{
  "count": 42,
  "next": "https://jumpserver.example.com/api/v1/blockchain/investigations/?page=2",
  "previous": null,
  "results": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "case_number": "CASE-2025-001",
      "title": "Cybercrime Investigation",
      "description": "Investigation into data breach incident",
      "status": "active",
      "created_by": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "created_by_display": "investigator_alice",
      "created_at": "2025-11-09T10:00:00Z",
      "archived_by": null,
      "archived_by_display": null,
      "archived_at": null,
      "reopened_by": null,
      "reopened_at": null,
      "evidence_count": 5
    }
  ]
}
```

**Permissions**:
- **BlockchainInvestigator**: Can create and view own investigations
- **BlockchainAuditor**: Can view all investigations (read-only)
- **BlockchainCourt**: Can view all investigations, archive/reopen

---

#### Create Investigation
```http
POST /api/v1/blockchain/investigations/
Content-Type: application/json
```

**Request Body**:
```json
{
  "case_number": "CASE-2025-002",
  "title": "Ransomware Attack Investigation",
  "description": "Investigation into ransomware attack on hospital systems"
}
```

**Response** (201 Created):
```json
{
  "id": "660e8400-e29b-41d4-a716-446655440001",
  "case_number": "CASE-2025-002",
  "title": "Ransomware Attack Investigation",
  "description": "Investigation into ransomware attack on hospital systems",
  "status": "active",
  "created_by": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "created_by_display": "court_judge",
  "created_at": "2025-11-09T11:30:00Z",
  "evidence_count": 0
}
```

**Permissions**:
- **BlockchainCourt**: Can create investigations
- **BlockchainInvestigator**: Cannot create (only Court can)

---

#### Archive Investigation
```http
POST /api/v1/blockchain/investigations/{id}/archive/
Content-Type: application/json
```

**Request Body**:
```json
{
  "reason": "Case closed - suspect convicted"
}
```

**Response** (200 OK):
```json
{
  "status": "success",
  "message": "Investigation CASE-2025-001 archived successfully",
  "cold_chain_transactions": [
    {
      "transaction_hash": "0xabc123...",
      "block_number": 12345,
      "timestamp": "2025-11-09T12:00:00Z"
    }
  ]
}
```

**Permissions**:
- **BlockchainCourt**: Can archive investigations
- **Others**: Cannot archive

**Note**: Archives all evidence to cold chain (immutable blockchain storage)

---

### Evidence

**Base Path**: `/api/v1/blockchain/evidence/`

#### Upload Evidence
```http
POST /api/v1/blockchain/evidence/
Content-Type: multipart/form-data
```

**Request Body** (multipart/form-data):
```
investigation: 550e8400-e29b-41d4-a716-446655440000
title: Suspicious Email Attachment
description: Malware sample extracted from phishing email
file: (binary file data)
```

**Response** (201 Created):
```json
{
  "id": "770e8400-e29b-41d4-a716-446655440002",
  "investigation": "550e8400-e29b-41d4-a716-446655440000",
  "investigation_case_number": "CASE-2025-001",
  "file_name": "malware_sample.exe",
  "file_size": 2048576,
  "file_hash_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "ipfs_cid": "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
  "description": "Malware sample extracted from phishing email",
  "uploaded_by": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "uploaded_by_display": "investigator_alice",
  "hot_chain_tx_hash": "0xdef456...",
  "cold_chain_tx_hash": null,
  "is_archived": false,
  "created_at": "2025-11-09T13:00:00Z"
}
```

**Workflow**:
1. File uploaded to IPFS (returns CID)
2. File hash (SHA-256) calculated
3. Metadata written to hot chain (Hyperledger Fabric)
4. Evidence record created in database

**Permissions**:
- **BlockchainInvestigator**: Can upload evidence
- **Others**: Cannot upload (read-only)

---

#### Verify Evidence Integrity
```http
GET /api/v1/blockchain/evidence/{id}/verify/
```

**Response** (200 OK):
```json
{
  "status": "verified",
  "evidence_id": "770e8400-e29b-41d4-a716-446655440002",
  "file_hash_database": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "file_hash_blockchain": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "ipfs_cid": "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
  "merkle_proof_valid": true,
  "blockchain_verified": true,
  "verified_at": "2025-11-09T14:00:00Z"
}
```

**Verification Steps**:
1. Retrieve file from IPFS
2. Calculate SHA-256 hash
3. Compare with database record
4. Verify merkle proof against blockchain
5. Return verification result

---

### Blockchain Transactions

**Base Path**: `/api/v1/blockchain/transactions/`

#### List Transactions
```http
GET /api/v1/blockchain/transactions/?chain_type=hot&investigation=550e8400-e29b-41d4-a716-446655440000
```

**Response** (200 OK):
```json
{
  "count": 5,
  "results": [
    {
      "id": "880e8400-e29b-41d4-a716-446655440003",
      "transaction_hash": "0xabc123def456...",
      "chain_type": "hot",
      "evidence_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      "ipfs_cid": "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
      "user": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "user_display": "investigator_alice",
      "user_guid": null,
      "is_anonymous": false,
      "merkle_proof": {...},
      "metadata": {
        "case_number": "CASE-2025-001",
        "evidence_type": "digital"
      },
      "created_at": "2025-11-09T13:00:00Z"
    }
  ]
}
```

**Permissions**:
- **BlockchainAuditor**: Can view all transactions
- **BlockchainInvestigator**: Can view own transactions only

---

### GUID Resolution

**Base Path**: `/api/v1/blockchain/guid/`

#### Resolve Anonymous GUID
```http
POST /api/v1/blockchain/guid/resolve/
Content-Type: application/json
```

**Request Body**:
```json
{
  "guid": "a3d2f5e8-9b4c-4a1e-8f2d-6c7b9a0e1f3d",
  "reason": "Court order #12345 - identity disclosure required"
}
```

**Response** (200 OK):
```json
{
  "status": "success",
  "guid": "a3d2f5e8-9b4c-4a1e-8f2d-6c7b9a0e1f3d",
  "user_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "username": "investigator_alice",
  "full_name": "Alice Johnson",
  "resolved_by": "court_judge",
  "reason": "Court order #12345 - identity disclosure required"
}
```

**Permissions**:
- **BlockchainCourt**: Can resolve GUIDs (requires `blockchain.resolve_guid` permission)
- **Others**: Cannot resolve (403 Forbidden)

**Audit Trail**: All GUID resolutions are logged with reason and court user identity.

---

## UI Enhancement APIs

### Tags

**Base Path**: `/api/v1/blockchain/tags/`

#### List All Tags
```http
GET /api/v1/blockchain/tags/?category=crime_type
```

**Response** (200 OK):
```json
{
  "count": 12,
  "results": [
    {
      "id": "990e8400-e29b-41d4-a716-446655440004",
      "name": "Cybercrime",
      "category": "crime_type",
      "color": "#FF5733",
      "description": "Crimes involving computers and networks",
      "created_by": "00000000-0000-0000-0000-000000000001",
      "created_by_display": "admin",
      "created_at": "2025-11-01T10:00:00Z",
      "tagged_count": 15
    },
    {
      "id": "aa0e8400-e29b-41d4-a716-446655440005",
      "name": "High Priority",
      "category": "priority",
      "color": "#DC143C",
      "description": "Cases requiring immediate attention",
      "created_by": "00000000-0000-0000-0000-000000000001",
      "created_by_display": "admin",
      "created_at": "2025-11-01T10:05:00Z",
      "tagged_count": 8
    }
  ]
}
```

**Permissions**:
- **All blockchain roles**: Can view tags
- **SystemAdmin**: Can create/update/delete tags

---

#### Create Tag
```http
POST /api/v1/blockchain/tags/
Content-Type: application/json
```

**Request Body**:
```json
{
  "name": "Fraud",
  "category": "crime_type",
  "color": "#FFD700",
  "description": "Financial fraud cases"
}
```

**Response** (201 Created):
```json
{
  "id": "bb0e8400-e29b-41d4-a716-446655440006",
  "name": "Fraud",
  "category": "crime_type",
  "color": "#FFD700",
  "description": "Financial fraud cases",
  "created_by": "00000000-0000-0000-0000-000000000001",
  "created_by_display": "admin",
  "created_at": "2025-11-09T15:00:00Z",
  "tagged_count": 0
}
```

**Permissions**: SystemAdmin only

---

### Investigation Tags

**Base Path**: `/api/v1/blockchain/investigation-tags/`

#### Assign Tag to Investigation
```http
POST /api/v1/blockchain/investigation-tags/
Content-Type: application/json
```

**Request Body**:
```json
{
  "investigation": "550e8400-e29b-41d4-a716-446655440000",
  "tag": "990e8400-e29b-41d4-a716-446655440004"
}
```

**Response** (201 Created):
```json
{
  "id": "cc0e8400-e29b-41d4-a716-446655440007",
  "investigation": "550e8400-e29b-41d4-a716-446655440000",
  "tag": "990e8400-e29b-41d4-a716-446655440004",
  "tag_name": "Cybercrime",
  "tag_color": "#FF5733",
  "tag_category": "crime_type",
  "added_by": "00000000-0000-0000-0000-000000000001",
  "added_by_display": "admin",
  "added_at": "2025-11-09T15:30:00Z"
}
```

**Validation**:
- Maximum 3 tags per investigation
- Cannot assign duplicate tag to same investigation

**Error Response** (400 Bad Request):
```json
{
  "error": "Maximum 3 tags allowed per investigation. Remove an existing tag first."
}
```

**Permissions**: SystemAdmin only

---

#### Remove Tag from Investigation
```http
DELETE /api/v1/blockchain/investigation-tags/{id}/
```

**Response** (204 No Content)

**Activity Tracking**: Automatically creates `tag_changed` activity entry

---

### Investigation Notes

**Base Path**: `/api/v1/blockchain/notes/`

#### Add Note to Investigation
```http
POST /api/v1/blockchain/notes/
Content-Type: application/json
```

**Request Body**:
```json
{
  "investigation": "550e8400-e29b-41d4-a716-446655440000",
  "content": "Suspect identified through IP address correlation. Requesting search warrant."
}
```

**Response** (201 Created):
```json
{
  "id": "dd0e8400-e29b-41d4-a716-446655440008",
  "investigation": "550e8400-e29b-41d4-a716-446655440000",
  "content": "Suspect identified through IP address correlation. Requesting search warrant.",
  "note_hash": "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8",
  "created_by": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "created_by_display": "investigator_alice",
  "created_at": "2025-11-09T16:00:00Z",
  "blockchain_tx": null,
  "blockchain_tx_hash": null,
  "is_blockchain_verified": false
}
```

**Blockchain Logging**:
1. Note hash (SHA-256) calculated automatically on save
2. Note logged to blockchain asynchronously (via signal handler)
3. `blockchain_tx` field updated when confirmed on chain
4. `is_blockchain_verified` becomes `true` after blockchain confirmation

**Permissions**:
- **BlockchainInvestigator**: Can create notes
- **All blockchain roles**: Can view notes (read-only)

---

#### List Notes for Investigation
```http
GET /api/v1/blockchain/notes/?investigation_id=550e8400-e29b-41d4-a716-446655440000
```

**Response** (200 OK):
```json
{
  "count": 3,
  "results": [
    {
      "id": "dd0e8400-e29b-41d4-a716-446655440008",
      "investigation": "550e8400-e29b-41d4-a716-446655440000",
      "content": "Suspect identified through IP address correlation.",
      "note_hash": "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8",
      "created_by": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "created_by_display": "investigator_alice",
      "created_at": "2025-11-09T16:00:00Z",
      "blockchain_tx_hash": "0x123abc...",
      "is_blockchain_verified": true
    }
  ]
}
```

---

### Investigation Activities

**Base Path**: `/api/v1/blockchain/activities/`

#### List Activities for Investigation
```http
GET /api/v1/blockchain/activities/?investigation_id=550e8400-e29b-41d4-a716-446655440000&recent_only=true
```

**Query Parameters**:
- `investigation_id` (UUID): Filter by investigation
- `recent_only` (boolean): Show only activities from last 24 hours
- `unviewed_only` (boolean): Show only activities not viewed by current user
- `activity_type` (string): Filter by type (`evidence_added`, `note_added`, `tag_changed`, `status_changed`)

**Response** (200 OK):
```json
{
  "count": 8,
  "results": [
    {
      "id": "ee0e8400-e29b-41d4-a716-446655440009",
      "investigation": "550e8400-e29b-41d4-a716-446655440000",
      "activity_type": "evidence_added",
      "description": "Evidence file \"malware_sample.exe\" was added to the investigation",
      "performed_by": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "performed_by_display": "investigator_alice",
      "timestamp": "2025-11-09T13:00:00Z",
      "is_recent": true,
      "viewed_by": ["admin", "court_judge"],
      "viewed_by_usernames": ["admin", "court_judge"]
    },
    {
      "id": "ff0e8400-e29b-41d4-a716-446655440010",
      "investigation": "550e8400-e29b-41d4-a716-446655440000",
      "activity_type": "note_added",
      "description": "Investigation note was added by investigator_alice",
      "performed_by": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "performed_by_display": "investigator_alice",
      "timestamp": "2025-11-09T16:00:00Z",
      "is_recent": true,
      "viewed_by": [],
      "viewed_by_usernames": []
    }
  ]
}
```

**Activity Types**:
- `evidence_added`: Evidence file uploaded
- `note_added`: Investigation note created
- `tag_changed`: Tag assigned or removed
- `status_changed`: Investigation status changed (archived/reopened)
- `assigned`: Investigator assigned to case (future feature)

**24-Hour Indicator**:
- `is_recent`: Returns `true` if activity timestamp within last 24 hours
- Used for UI badges/notifications

---

#### Mark Activity as Viewed
```http
POST /api/v1/blockchain/activities/{id}/mark_viewed/
```

**Response** (200 OK):
```json
{
  "status": "success",
  "activity_id": "ee0e8400-e29b-41d4-a716-446655440009",
  "viewed_by": ["admin", "court_judge", "investigator_alice"]
}
```

**Use Case**: Track which users have seen each activity (for "unread" indicators)

---

## Role-Based Access Control

### Role Permission Matrix

| Operation | SystemAdmin | BlockchainInvestigator | BlockchainAuditor | BlockchainCourt |
|-----------|-------------|------------------------|-------------------|-----------------|
| **Investigations** |
| Create | ✅ | ❌ | ❌ | ✅ |
| View All | ✅ | ❌ | ✅ | ✅ |
| View Own | ✅ | ✅ | ✅ | ✅ |
| Archive | ✅ | ❌ | ❌ | ✅ |
| Reopen | ✅ | ❌ | ❌ | ✅ |
| **Evidence** |
| Upload | ❌ | ✅ | ❌ | ❌ |
| View | ✅ | ✅ | ✅ | ✅ |
| Download | ✅ | ✅ | ✅ | ✅ |
| Verify | ✅ | ✅ | ✅ | ✅ |
| **Tags** |
| Create/Edit/Delete | ✅ | ❌ | ❌ | ❌ |
| View | ✅ | ✅ | ✅ | ✅ |
| Assign to Investigation | ❌ | ❌ | ❌ | ✅ |
| **Notes** |
| Create | ❌ | ✅ | ❌ | ❌ |
| View | ✅ | ✅ | ✅ | ✅ |
| **Activities** |
| View | ✅ | ✅ | ✅ | ✅ |
| Mark Viewed | ✅ | ✅ | ✅ | ✅ |
| **GUID Resolution** |
| Resolve | ✅ | ❌ | ❌ | ✅ |

### Role IDs (for API filtering)

```python
ALLOWED_BLOCKCHAIN_ROLE_IDS = [
    '00000000-0000-0000-0000-000000000001',  # SystemAdmin
    '00000000-0000-0000-0000-000000000008',  # BlockchainInvestigator
    '00000000-0000-0000-0000-000000000009',  # BlockchainAuditor
    '00000000-0000-0000-0000-00000000000A',  # BlockchainCourt
]
```

**Legacy Role Blocking**: Legacy JumpServer roles (SystemAuditor, OrgAdmin, etc.) are explicitly excluded from blockchain APIs and will receive empty querysets.

---

## Error Responses

### 400 Bad Request
```json
{
  "error": "Maximum 3 tags allowed per investigation. Remove an existing tag first."
}
```

**Causes**:
- Validation errors (e.g., max 3 tags, duplicate tag)
- Missing required fields
- Invalid data format

---

### 403 Forbidden
```json
{
  "error": "You do not have permission to perform this action."
}
```

**Causes**:
- User does not have required blockchain role
- Insufficient RBAC permissions
- Legacy role attempting blockchain access

---

### 404 Not Found
```json
{
  "error": "Investigation not found"
}
```

**Causes**:
- Resource does not exist
- User does not have access to resource (filtered by queryset)

---

### 500 Internal Server Error
```json
{
  "error": "Failed to upload evidence to IPFS: connection timeout"
}
```

**Causes**:
- Blockchain connection failure
- IPFS storage failure
- Database errors

---

## Testing the APIs

### Using curl with mTLS certificate:

```bash
# List investigations
curl -k https://jumpserver.example.com/api/v1/blockchain/investigations/ \
  --cert /path/to/cert.p12:password \
  --cert-type P12

# Upload evidence (multipart form)
curl -k https://jumpserver.example.com/api/v1/blockchain/evidence/ \
  --cert /path/to/cert.p12:password \
  --cert-type P12 \
  -F "investigation=550e8400-e29b-41d4-a716-446655440000" \
  -F "title=Suspicious File" \
  -F "description=Malware sample" \
  -F "file=@/path/to/sample.exe"

# Create tag (admin only)
curl -k https://jumpserver.example.com/api/v1/blockchain/tags/ \
  --cert /path/to/admin.p12:password \
  --cert-type P12 \
  -H "Content-Type: application/json" \
  -d '{"name":"High Priority","category":"priority","color":"#FF0000"}'

# Add note to investigation
curl -k https://jumpserver.example.com/api/v1/blockchain/notes/ \
  --cert /path/to/investigator.p12:password \
  --cert-type P12 \
  -H "Content-Type: application/json" \
  -d '{"investigation":"550e8400-e29b-41d4-a716-446655440000","content":"Suspect identified"}'

# View recent activities
curl -k https://jumpserver.example.com/api/v1/blockchain/activities/?investigation_id=550e8400-e29b-41d4-a716-446655440000&recent_only=true \
  --cert /path/to/cert.p12:password \
  --cert-type P12
```

---

## Next Steps for UI Development

1. **Create React components** for each API endpoint
2. **Implement role-based routing** (`/admin-dashboard/` vs `/dashboard/`)
3. **Add activity indicators** (24-hour badges, unread counts)
4. **Build investigation detail page** with tabs for:
   - Evidence list
   - Blockchain transaction history
   - Notes timeline
   - Activity feed
   - Tag management
5. **Implement search and filtering** by tags, status, date ranges
6. **Add export report functionality** (PDF/CSV generation)
7. **Create activity graphs** (evidence addition frequency over time)

---

**END OF DOCUMENTATION**
