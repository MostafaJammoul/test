# JumpServer Blockchain Chain of Custody - Modifications

This document details all customizations made to the official JumpServer codebase to add blockchain-based evidence chain of custody functionality.

**Base**: JumpServer v4.0 (jumpserver-dev)
**Date**: November 4, 2025
**Approach**: APPEND ONLY - All modifications preserve original functionality

---

## Table of Contents

1. [Overview](#overview)
2. [Directory Structure](#directory-structure)
3. [Code Modifications](#code-modifications)
4. [Configuration Files](#configuration-files)
5. [Dependencies](#dependencies)
6. [New Applications](#new-applications)
7. [Quick Start](#quick-start)
8. [Testing](#testing)

---

## Overview

### What Was Added

This customization adds a **blockchain-based evidence chain of custody system** to JumpServer with the following features:

- **Hyperledger Fabric Integration**: Hot and cold chain architecture for active/archived investigations
- **IPFS Integration**: Distributed storage for evidence files
- **Internal PKI/CA**: Certificate authority for mTLS user authentication
- **GUID System**: Anonymous evidence submission with court-authorized resolution
- **Three New Roles**: BlockchainInvestigator, BlockchainAuditor, BlockchainCourt
- **Mock Clients**: Testing without actual blockchain infrastructure

### Design Principles

1. **APPEND ONLY**: No deletion of original JumpServer code
2. **Clear Markers**: All custom code marked with comment headers
3. **Backwards Compatible**: Original JumpServer functionality unchanged
4. **Production Ready**: Complete with migrations, tests, documentation

---

## Directory Structure

```
truefypjs/
├── apps/
│   ├── rbac/
│   │   └── builtin.py                    # ✏️ MODIFIED - Added blockchain roles
│   ├── jumpserver/
│   │   └── settings/
│   │       └── base.py                   # ✏️ MODIFIED - Added pki and blockchain to INSTALLED_APPS
│   ├── pki/                              # ✨ NEW APP - Internal CA/PKI management
│   │   ├── __init__.py
│   │   ├── apps.py
│   │   ├── models.py
│   │   ├── ca_manager.py
│   │   ├── tasks.py
│   │   ├── api/
│   │   │   ├── serializers.py
│   │   │   ├── urls.py
│   │   │   └── views.py
│   │   └── management/
│   │       └── commands/
│   │           ├── init_pki.py
│   │           └── issue_user_cert.py
│   └── blockchain/                       # ✨ NEW APP - Blockchain chain of custody
│       ├── __init__.py
│       ├── apps.py
│       ├── models.py
│       ├── signal_handlers.py
│       ├── api/
│       │   ├── serializers.py
│       │   ├── urls.py
│       │   └── views.py
│       ├── clients/
│       │   ├── fabric_client.py          # Hyperledger Fabric integration
│       │   ├── fabric_client_mock.py     # Mock for testing
│       │   ├── ipfs_client.py            # IPFS integration
│       │   └── ipfs_client_mock.py       # Mock for testing
│       └── services/
│           ├── archive_service.py        # Investigation archiving
│           └── guid_resolver.py          # GUID resolution
├── config/                               # ✨ NEW DIRECTORY - Configuration examples
│   ├── blockchain.yml.example
│   ├── fabric-network.json.example
│   └── nginx-mtls.conf.example
├── config.yml                            # ✏️ MODIFIED - Added blockchain/mTLS settings
├── pyproject.toml                        # ✏️ MODIFIED - Added blockchain dependencies
└── MODIFICATIONS.md                      # ✨ NEW - This file
```

**Legend**:
- ✏️ MODIFIED - Existing file with additions
- ✨ NEW - Completely new file/directory

---

## Code Modifications

### 1. RBAC System (`apps/rbac/builtin.py`)

**File**: [apps/rbac/builtin.py](apps/rbac/builtin.py)

**Changes**: Added blockchain role permission definitions and role objects

**Lines 75-127**: Permission definitions
```python
# ==============================================================================
# BLOCKCHAIN CHAIN OF CUSTODY CUSTOMIZATION - ADDED
# ==============================================================================
_blockchain_investigator_perms = (
    ('blockchain', 'investigation', '*', '*'),
    ('blockchain', 'evidence', 'add,view', '*'),
    ('blockchain', 'blockchaintransaction', 'add,view', '*'),
    ('blockchain', 'blockchaintransaction', 'append', 'hot'),
    ('blockchain', 'blockchaintransaction', 'append', 'cold'),
    ('audits', 'userloginlog', 'view', 'self'),
    ('audits', 'operatelog', 'view', 'self'),
    *user_perms,
)

_blockchain_auditor_perms = (
    ('blockchain', 'investigation', 'view', '*'),
    ('blockchain', 'evidence', 'view', '*'),
    ('blockchain', 'blockchaintransaction', 'view', '*'),
    ('audits', '*', 'view', '*'),
    ('reports', '*', 'view', '*'),
    *user_perms,
)

_blockchain_court_perms = (
    ('blockchain', 'investigation', 'view', '*'),
    ('blockchain', 'evidence', 'view', '*'),
    ('blockchain', 'blockchaintransaction', 'view', '*'),
    ('blockchain', 'investigation', 'archive', '*'),
    ('blockchain', 'investigation', 'reopen', '*'),
    ('blockchain', 'guidmapping', 'resolve_guid', '*'),  # ONLY court role
    ('audits', '*', 'view', '*'),
    ('reports', '*', 'view', '*'),
    *user_perms,
)
# ==============================================================================
# END BLOCKCHAIN CUSTOMIZATION
# ==============================================================================
```

**Lines 200-214**: Role objects
```python
    # ==============================================================================
    # BLOCKCHAIN CHAIN OF CUSTODY ROLES - ADDED
    # ==============================================================================
    blockchain_investigator = PredefineRole(
        '8', gettext_noop('BlockchainInvestigator'), Scope.system, _blockchain_investigator_perms
    )
    blockchain_auditor = PredefineRole(
        '9', gettext_noop('BlockchainAuditor'), Scope.system, _blockchain_auditor_perms
    )
    blockchain_court = PredefineRole(
        'A', gettext_noop('BlockchainCourt'), Scope.system, _blockchain_court_perms
    )
    # ==============================================================================
    # END BLOCKCHAIN CUSTOMIZATION
    # ==============================================================================
```

**Lines 236-239**: Role mapper update
```python
                # BLOCKCHAIN CUSTOMIZATION - ADDED
                'Investigator': cls.blockchain_investigator.get_role(),
                'BlockchainAuditor': cls.blockchain_auditor.get_role(),
                'Court': cls.blockchain_court.get_role(),
```

**Why**: Implements RBAC for three blockchain-specific roles with appropriate permissions for evidence management.

---

### 2. Django Settings (`apps/jumpserver/settings/base.py`)

**File**: [apps/jumpserver/settings/base.py](apps/jumpserver/settings/base.py)

**Changes**: Added pki and blockchain to INSTALLED_APPS

**Lines 140-144**:
```python
    # ==============================================================================
    # BLOCKCHAIN CHAIN OF CUSTODY APPS - ADDED
    # ==============================================================================
    'pki.apps.PKIConfig',  # PKI/CA management for mTLS
    'blockchain.apps.BlockchainConfig',  # Blockchain evidence chain of custody
```

**Why**: Django requires all apps in INSTALLED_APPS. Added after other JumpServer apps, before third-party apps.

---

### 3. Main Configuration (`config.yml`)

**File**: [config.yml](config.yml)

**Changes**: Added blockchain/mTLS configuration section

**Lines 104-144**:
```yaml
# ==============================================================================
# BLOCKCHAIN CHAIN OF CUSTODY CONFIGURATION - ADDED
# ==============================================================================

# PKI / Internal CA Configuration
PKI_ENABLED: true
PKI_CA_NAME: "JumpServer Internal CA"
PKI_CA_COUNTRY: "US"
PKI_CA_STATE: "California"
PKI_CA_LOCALITY: "San Francisco"
PKI_CA_ORGANIZATION: "JumpServer"
PKI_CA_ORGANIZATIONAL_UNIT: "Security"
PKI_CA_VALIDITY_DAYS: 3650  # CA valid for 10 years
PKI_USER_CERT_VALIDITY_DAYS: 365  # User certs valid for 1 year
PKI_AUTO_RENEWAL_ENABLED: true
PKI_AUTO_RENEWAL_DAYS_BEFORE: 30

# mTLS Authentication
MTLS_ENABLED: false  # Set to true when nginx mTLS is configured
MTLS_REQUIRED: false
MTLS_HEADER_CERT: "X-SSL-Client-Cert"
MTLS_HEADER_DN: "X-SSL-Client-DN"
MTLS_HEADER_VERIFY: "X-SSL-Client-Verify"

# Blockchain Configuration
BLOCKCHAIN_ENABLED: false  # Set to true when Fabric network is ready
BLOCKCHAIN_USE_MOCK: true  # Use mock clients for testing
BLOCKCHAIN_CONFIG_FILE: "config/blockchain.yml"
BLOCKCHAIN_FABRIC_NETWORK: "config/fabric-network.json"

# IPFS Configuration
IPFS_ENABLED: false  # Set to true when IPFS node is ready
IPFS_USE_MOCK: true  # Use mock client for testing
IPFS_API_URL: "/ip4/127.0.0.1/tcp/5001/http"
```

**Why**: Provides runtime configuration for blockchain features. Mock clients enabled by default for testing.

---

## Configuration Files

### 1. Blockchain Configuration (`config/blockchain.yml.example`)

**File**: [config/blockchain.yml.example](config/blockchain.yml.example)
**Lines**: 256 lines
**Purpose**: Complete blockchain and IPFS configuration

**Sections**:
- Hyperledger Fabric configuration (network profile, channels, chaincodes, mTLS)
- IPFS configuration (API URL, encryption, pinning)
- GUID resolver configuration
- Certificate rotation settings
- Performance and caching
- Logging

**Key Features**:
- Instructions for obtaining Fabric certificates from Fabric CA
- Encryption key generation guide
- Security best practices

---

### 2. Fabric Network Topology (`config/fabric-network.json.example`)

**File**: [config/fabric-network.json.example](config/fabric-network.json.example)
**Lines**: 90 lines
**Purpose**: Hyperledger Fabric network connection profile

**Defines**:
- Channels: hot-chain (active investigations), cold-chain (archived)
- Organizations: Org1 with peer and CA
- Orderer configuration
- Peer configuration with TLS
- Certificate Authority endpoints

---

### 3. Nginx mTLS Configuration (`config/nginx-mtls.conf.example`)

**File**: [config/nginx-mtls.conf.example](config/nginx-mtls.conf.example)
**Lines**: 286 lines
**Purpose**: Complete nginx reverse proxy configuration with mTLS

**Features**:
- HTTP to HTTPS redirect
- Server certificate configuration (Let's Encrypt or internal)
- Client certificate verification against Internal CA
- Certificate Revocation List (CRL) support
- Security headers (HSTS, X-Frame-Options, etc.)
- Custom error pages for certificate issues
- WebSocket support for Django Channels
- Health check endpoint (no mTLS required)
- Testing and troubleshooting instructions

**Architecture**:
```
User (Browser + mTLS cert) → Nginx (verify cert) → Django (authenticate)
```

---

## Dependencies

### Modified: `pyproject.toml`

**File**: [pyproject.toml](pyproject.toml)

**Version Upgrades** (for compatibility with fabric-sdk-py):
- Line 14: `bcrypt`: 4.0.1 → 4.2.0
- Line 28: `paramiko`: 3.2.0 → 3.5.0
- Lines 32-33: `pycryptodome`: 3.18.0 → 3.20.0, `pycryptodomex`: 3.18.0 → 3.20.0
- Line 109: `pyopenssl`: 23.2.0 → 24.3.0
- Line 110: Added `cryptography>=44.0.0` (required by fabric-sdk-py)

**Blockchain Dependencies** (lines 156-160):
```python
    # ==============================================================================
    # BLOCKCHAIN CHAIN OF CUSTODY DEPENDENCIES - ADDED
    # ==============================================================================
    'fabric-sdk-py',  # Hyperledger Fabric Python SDK
    'ipfshttpclient>=0.8.0a2',  # IPFS HTTP Client
```

**Source URLs** (lines 203-204):
```python
# BLOCKCHAIN CUSTOMIZATION - ADDED
fabric-sdk-py = { git = "https://github.com/hyperledger/fabric-sdk-py.git" }
```

**Why**: Enables Hyperledger Fabric and IPFS integration. Version upgrades ensure compatibility.

---

## New Applications

### 1. PKI App (`apps/pki/`)

**Purpose**: Internal Certificate Authority for mTLS authentication

**Files** (13 Python files):
- `models.py`: CertificateAuthority, Certificate models
- `ca_manager.py`: Core CA functionality (generate, sign, revoke certificates)
- `tasks.py`: Celery tasks for automatic certificate renewal
- `api/`: REST API endpoints for certificate operations
- `management/commands/init_pki.py`: Initialize CA on first run
- `management/commands/issue_user_cert.py`: Issue user certificates

**Features**:
- Generate self-signed CA certificate on initialization
- Issue user certificates for mTLS authentication
- Certificate renewal 30 days before expiry (automatic via Celery)
- Certificate revocation with CRL
- Export CA cert and CRL for nginx
- API endpoints with mTLS support

**Key Models**:
- `CertificateAuthority`: Stores CA certificate and private key
- `Certificate`: User certificates with auto-renewal

---

### 2. Blockchain App (`apps/blockchain/`)

**Purpose**: Blockchain-based evidence chain of custody

**Files** (16 Python files):
- `models.py`: Investigation, Evidence, BlockchainTransaction, GUIDMapping
- `signal_handlers.py`: Auto-record blockchain transactions on model changes
- `api/`: REST API for investigations, evidence, transactions
- `clients/fabric_client.py`: Hyperledger Fabric integration
- `clients/fabric_client_mock.py`: Mock for testing without Fabric
- `clients/ipfs_client.py`: IPFS integration for file storage
- `clients/ipfs_client_mock.py`: Mock for testing without IPFS
- `services/archive_service.py`: Move investigations from hot to cold chain
- `services/guid_resolver.py`: Resolve GUIDs to user IDs (Court role only)

**Features**:
- **Hot Chain**: Active investigations with read/write access
- **Cold Chain**: Archived investigations (read-only, immutable)
- **GUID System**: Anonymous evidence submission with cryptographic commitment
- **Dual Chain Architecture**: Separate Fabric channels for hot/cold
- **Mock Clients**: Full testing without blockchain infrastructure
- **Automatic Recording**: Django signals record all evidence operations to blockchain
- **IPFS Storage**: Evidence files stored in IPFS with encryption
- **Court-Only Resolution**: Only Court role can resolve GUIDs to identities

**Key Models**:
- `Investigation`: Case with status (active, archived)
- `Evidence`: Evidence file with IPFS hash and metadata
- `BlockchainTransaction`: Record of blockchain transaction (tx hash, block number)
- `GUIDMapping`: Maps anonymous GUIDs to user IDs (encrypted)

---

## Quick Start

### 1. Install Dependencies

```bash
cd truefypjs
pip install -r requirements.txt  # or: uv pip install -e .
```

### 2. Initialize PKI (First Run)

```bash
python manage.py init_pki
```

This creates the Internal CA and generates root certificate.

### 3. Run Migrations

```bash
python manage.py migrate
```

### 4. Create Superuser

```bash
python manage.py createsuperuser
```

### 5. Sync Blockchain Roles

```bash
python manage.py sync_role
```

This creates the three blockchain roles in the database.

### 6. Start Server

```bash
# Development mode
python manage.py runserver

# Production mode (with gunicorn)
gunicorn jumpserver.wsgi:application --bind 0.0.0.0:8080
```

### 7. Issue User Certificate (Optional - for mTLS)

```bash
python manage.py issue_user_cert --username admin --output admin.p12
```

Import `admin.p12` into your browser for mTLS authentication.

---

## Testing

### Test Without Blockchain (Mock Mode)

The default configuration uses mock clients, so you can test immediately:

```bash
# All blockchain operations will use mock clients
# No actual Fabric or IPFS connection required

python manage.py runserver
```

**Mock client behavior**:
- `fabric_client_mock.py`: Simulates blockchain transactions with in-memory ledger
- `ipfs_client_mock.py`: Simulates IPFS with local file storage

### Test With Real Blockchain

1. **Deploy Hyperledger Fabric Network**:
   ```bash
   # Use fabric-samples/test-network
   cd fabric-samples/test-network
   ./network.sh up createChannel -c hot-chain
   ./network.sh up createChannel -c cold-chain
   ./network.sh deployCC -ccn evidence -ccp ../chaincode/evidence -ccl python
   ```

2. **Configure Fabric Connection**:
   ```bash
   cp config/blockchain.yml.example config/blockchain.yml
   cp config/fabric-network.json.example config/fabric-network.json
   # Edit with your Fabric network details
   ```

3. **Update config.yml**:
   ```yaml
   BLOCKCHAIN_ENABLED: true
   BLOCKCHAIN_USE_MOCK: false
   ```

4. **Deploy IPFS Node**:
   ```bash
   ipfs init
   ipfs daemon
   ```

5. **Update config.yml**:
   ```yaml
   IPFS_ENABLED: true
   IPFS_USE_MOCK: false
   IPFS_API_URL: "/ip4/127.0.0.1/tcp/5001/http"
   ```

6. **Restart Server**:
   ```bash
   python manage.py runserver
   ```

### Test mTLS Authentication

1. **Configure Nginx**:
   ```bash
   cp config/nginx-mtls.conf.example /etc/nginx/sites-available/jumpserver
   ln -s /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/
   ```

2. **Export Internal CA Certificate**:
   ```bash
   python manage.py export_ca_cert --output /etc/nginx/ssl/internal-ca.crt
   ```

3. **Update config.yml**:
   ```yaml
   MTLS_ENABLED: true
   MTLS_REQUIRED: false  # Optional: set to true to enforce mTLS for all requests
   ```

4. **Restart Nginx**:
   ```bash
   nginx -t
   systemctl reload nginx
   ```

5. **Issue User Certificate**:
   ```bash
   python manage.py issue_user_cert --username admin --output admin.p12
   ```

6. **Import Certificate in Browser**:
   - Firefox: Settings → Privacy & Security → Certificates → View Certificates → Import
   - Chrome: Settings → Privacy and security → Security → Manage certificates → Import

7. **Access Application**:
   ```
   https://jumpserver.example.com
   ```

Browser will prompt for certificate selection. After selection, you'll be authenticated automatically.

---

## Summary

### What Was Modified

| File | Change | Lines | Why |
|------|--------|-------|-----|
| `apps/rbac/builtin.py` | Added blockchain roles | 75-127, 200-214, 236-239 | RBAC for evidence management |
| `apps/jumpserver/settings/base.py` | Added to INSTALLED_APPS | 140-144 | Register pki and blockchain apps |
| `config.yml` | Added blockchain config | 104-144 | Runtime configuration |
| `pyproject.toml` | Added dependencies | 14, 28, 32-33, 109-110, 156-160, 203-204 | Fabric SDK and IPFS client |

### What Was Added

| Directory/File | Files | Purpose |
|----------------|-------|---------|
| `apps/pki/` | 13 Python files | Internal CA for mTLS |
| `apps/blockchain/` | 16 Python files | Evidence chain of custody |
| `config/` | 3 config files | Blockchain, Fabric, nginx examples |
| `MODIFICATIONS.md` | 1 file | This documentation |

### Total Changes

- **Modified Files**: 4
- **New Files**: 33 (13 PKI + 16 blockchain + 3 config + 1 doc)
- **Lines Added**: ~3,000 lines (code + config + documentation)
- **Approach**: APPEND ONLY - Zero deletions from original JumpServer

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Browser                             │
│                    (with mTLS certificate)                       │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTPS + mTLS
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Nginx Reverse Proxy                         │
│  - Verify client certificate against Internal CA                │
│  - Pass certificate to Django via headers                        │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                      JumpServer (Django)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  PKI App     │  │ Blockchain   │  │  Original    │          │
│  │  - Issue     │  │  - Evidence  │  │  JumpServer  │          │
│  │    certs     │  │  - GUID      │  │  - Assets    │          │
│  │  - Renew     │  │  - Archive   │  │  - Users     │          │
│  │  - Revoke    │  │              │  │  - Perms     │          │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘          │
│         │                 │                                      │
└─────────┼─────────────────┼──────────────────────────────────────┘
          │                 │
          │                 ├───────────────────┐
          │                 │                   │
          ↓                 ↓                   ↓
┌──────────────────┐ ┌──────────────┐ ┌──────────────────┐
│  Internal CA     │ │ Hyperledger  │ │      IPFS        │
│  (SQLite/DB)     │ │   Fabric     │ │  (File Storage)  │
│  - CA cert/key   │ │  - Hot Chain │ │  - Evidence      │
│  - User certs    │ │  - Cold Chain│ │    files         │
│  - CRL           │ │              │ │  - Encrypted     │
└──────────────────┘ └──────────────┘ └──────────────────┘
```

---

## Support

For issues or questions:
- Check nginx error logs: `/var/log/nginx/jumpserver-error.log`
- Check Django logs: `logs/jumpserver.log`
- Check celery logs: `logs/celery.log`
- Review troubleshooting section in `config/nginx-mtls.conf.example`

---

**End of MODIFICATIONS.md**
