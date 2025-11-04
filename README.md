# JumpServer Blockchain Chain of Custody

Complete blockchain-based evidence management system built on JumpServer with Hyperledger Fabric and IPFS integration.

---

## 🚀 Quick Start (Ubuntu)

```bash
# 1. Make script executable
chmod +x setup.sh

# 2. Run setup (installs everything + mTLS + PostgreSQL)
./setup.sh

# Takes 15-20 minutes
# - Installs all dependencies
# - Sets up PostgreSQL database (jumpserver/jsroot)
# - Initializes PKI (Internal CA)
# - Configures nginx with mTLS
# - Issues your first certificate
# - Starts server
```

**Access**:
- **With mTLS**: https://localhost (requires certificate)
- **Without mTLS**: http://localhost:8080 (direct backend)

**Note**: JumpServer uses a non-standard Django structure where `manage.py` is in `apps/` directory. All management commands in setup.sh are automatically run with `cd apps &&` prefix.

---

## ✨ Features

### Core Functionality

- ✅ **Blockchain Evidence Chain**: Immutable evidence tracking on Hyperledger Fabric
- ✅ **Hot/Cold Chain Architecture**: Active investigations on hot chain, archived on cold chain
- ✅ **IPFS Storage**: Distributed evidence file storage with encryption
- ✅ **mTLS Authentication**: Certificate-based authentication (non-repudiation)
- ✅ **Internal PKI/CA**: Automatic certificate issuance and renewal
- ✅ **GUID System**: Anonymous evidence submission with court-authorized resolution
- ✅ **Mock Clients**: Full testing without actual blockchain infrastructure

### Roles

| Role | ID | Permissions |
|------|----|-----------|
| **BlockchainInvestigator** | 8 | Create investigations, upload evidence, append to hot/cold chains |
| **BlockchainAuditor** | 9 | Read-only blockchain access, full audit logs |
| **BlockchainCourt** | A | Read-only + archive/reopen + GUID resolution |

---

## 📁 Project Structure

```
truefypjs/
├── setup.sh                    # ⚡ One-command setup script (with PostgreSQL)
├── config.yml                  # Main config (DB: jumpserver/jsroot@localhost:5432)
├── README.md                   # This file
├── SETUP.md                    # Detailed manual setup
├── MODIFICATIONS.md            # All code changes documented
├── DEPENDENCIES.md             # Dependency analysis
├── MTLS_TESTING.md            # mTLS verification guide
│
├── apps/
│   ├── pki/                   # Internal CA (13 files)
│   │   ├── models.py          # CertificateAuthority, Certificate
│   │   ├── ca_manager.py      # CA operations
│   │   ├── management/commands/
│   │   │   ├── init_pki.py
│   │   │   ├── export_ca_cert.py
│   │   │   ├── export_crl.py
│   │   │   └── issue_user_cert.py
│   │   └── api/               # REST API
│   │
│   ├── blockchain/            # Evidence chain of custody (16 files)
│   │   ├── models.py          # Investigation, Evidence, BlockchainTransaction
│   │   ├── clients/
│   │   │   ├── fabric_client.py       # Real Fabric
│   │   │   ├── fabric_client_mock.py  # Mock (testing)
│   │   │   ├── ipfs_client.py         # Real IPFS
│   │   │   └── ipfs_client_mock.py    # Mock (testing)
│   │   ├── services/
│   │   │   ├── archive_service.py     # Hot→Cold chain
│   │   │   └── guid_resolver.py       # GUID resolution
│   │   └── api/               # REST API
│   │
│   ├── rbac/builtin.py        # ✏️ Modified (blockchain roles)
│   └── jumpserver/settings/base.py  # ✏️ Modified (INSTALLED_APPS)
│
├── config/
│   ├── nginx-mtls.conf.example        # nginx mTLS config
│   ├── blockchain.yml.example         # Blockchain config
│   └── fabric-network.json.example    # Fabric topology
│
└── data/
    ├── logs/                  # Application logs
    ├── certs/
    │   ├── mtls/              # For nginx
    │   │   ├── internal-ca.crt    # CA certificate
    │   │   ├── internal-ca.crl    # Revocation list
    │   │   └── server.crt         # Server SSL
    │   └── pki/               # For users
    │       └── admin.p12          # User certificate
    └── uploads/               # Mock IPFS storage
```

---

## 🔐 mTLS Authentication

### Certificate Storage

**Primary (Database)**: All certificates encrypted in PostgreSQL
- Database: `jumpserver@localhost:5432/jumpserver`
- Table: `pki_certificateauthority` (CA cert + private key)
- Table: `pki_certificate` (User certs + private keys)

**Export (Filesystem)**: For nginx and browsers
- CA cert: `data/certs/mtls/internal-ca.crt`
- CRL: `data/certs/mtls/internal-ca.crl`
- User P12: `data/certs/pki/<username>.p12`

### Using mTLS

1. **Import certificate into browser**:
   - File: `data/certs/pki/admin.p12`
   - Password: `changeme123` (from setup.sh)
   - Firefox: Settings → Privacy & Security → Certificates → Import
   - Chrome: Settings → Privacy and security → Manage certificates

2. **Access application**:
   - Visit: https://localhost
   - Browser prompts for certificate
   - Select your certificate
   - Automatically authenticated!

3. **Test with curl**:
   ```bash
   curl https://localhost/api/health/ \
     --cert data/certs/pki/admin.p12 \
     --cert-type P12 \
     --pass "changeme123"
   ```

---

## 🧪 Testing Blockchain (Mock Mode)

### Mock Clients (No Fabric/IPFS Required)

**Default configuration**:
```yaml
# config.yml
BLOCKCHAIN_USE_MOCK: true
IPFS_USE_MOCK: true
```

**What happens**:
- Fabric transactions: Stored in-memory (Python dict)
- IPFS files: Stored in `data/uploads/`
- Mock transaction IDs: `mock_tx_abc123`
- Mock CIDs: `QmMock...`

### Create Investigation

```bash
# Note: All Django management commands must be run from the apps/ directory
cd apps
curl -X POST https://localhost/api/v1/blockchain/investigations/ \
  --cert data/certs/pki/admin.p12 \
  --cert-type P12 \
  --pass "changeme123" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Investigation",
    "description": "Testing blockchain chain of custody",
    "case_number": "CASE-2025-001"
  }'
```

### Upload Evidence

```bash
curl -X POST https://localhost/api/v1/blockchain/evidence/ \
  --cert data/certs/pki/admin.p12 \
  --cert-type P12 \
  --pass "changeme123" \
  -F "investigation=<investigation_id>" \
  -F "file=@evidence.jpg" \
  -F "description=Surveillance photo"
```

**Result**:
- File saved: `data/uploads/<hash>`
- Mock IPFS CID: `QmMock...`
- Mock Fabric tx: `mock_tx_def456`
- Database record with chain of custody

---

## 📚 Documentation

| File | Purpose |
|------|---------|
| **[setup.sh](setup.sh)** | Automated setup script |
| **[SETUP.md](SETUP.md)** | Complete manual instructions |
| **[MODIFICATIONS.md](MODIFICATIONS.md)** | All code changes documented |
| **[DEPENDENCIES.md](DEPENDENCIES.md)** | Dependency analysis & troubleshooting |
| **[MTLS_TESTING.md](MTLS_TESTING.md)** | Certificate storage & mTLS verification |

---

## 🔧 Configuration

### config.yml (Main Settings)

```yaml
# Database (PostgreSQL - auto-configured by setup.sh)
DB_ENGINE: postgresql
DB_HOST: 127.0.0.1
DB_PORT: 5432
DB_USER: jumpserver
DB_PASSWORD: jsroot
DB_NAME: jumpserver

# PKI (Internal CA)
PKI_ENABLED: true
PKI_CA_VALIDITY_DAYS: 3650
PKI_USER_CERT_VALIDITY_DAYS: 365

# mTLS
MTLS_ENABLED: true
MTLS_REQUIRED: false  # Set to true to enforce for all requests

# Blockchain (Mock mode by default)
BLOCKCHAIN_ENABLED: false
BLOCKCHAIN_USE_MOCK: true

# IPFS (Mock mode by default)
IPFS_ENABLED: false
IPFS_USE_MOCK: true
```

### Production Deployment

1. **PostgreSQL is already configured** (jumpserver/jsroot@localhost:5432)
   - Change password in production: Update `DB_PASSWORD` in config.yml

2. **Deploy real Fabric**:
   ```yaml
   BLOCKCHAIN_ENABLED: true
   BLOCKCHAIN_USE_MOCK: false
   ```

3. **Deploy real IPFS**:
   ```yaml
   IPFS_ENABLED: true
   IPFS_USE_MOCK: false
   ```

4. **Configure Fabric**: Edit `config/blockchain.yml`

---

## 📊 System Requirements

### Development (Mock Mode)

- **OS**: Ubuntu 20.04+ (or Debian-based)
- **Python**: 3.11+
- **RAM**: 4GB minimum
- **Disk**: 10GB
- **PostgreSQL**: 12+ (auto-installed)
- **Redis**: 6.x+ (auto-installed)

### Production (Real Blockchain)

- **OS**: Ubuntu 20.04+ (or Debian-based)
- **Python**: 3.11+
- **RAM**: 8GB+ (for Fabric nodes)
- **Disk**: 50GB+
- **PostgreSQL**: 12+ (auto-installed)
- **Redis**: 6.x+ (auto-installed)
- **Hyperledger Fabric**: 2.5+
- **IPFS**: 0.28+

---

## 🐛 Troubleshooting

### Common Issues

**1. fabric-sdk-py installation fails**:
```bash
sudo apt install -y build-essential gcc python3.11-dev libssl-dev
pip install 'git+https://github.com/hyperledger/fabric-sdk-py.git'
```

**2. Certificate not accepted by browser**:
- Check certificate is imported in browser
- Verify password: `changeme123`
- Check browser supports client certificates
- Try different browser (Firefox recommended)

**3. nginx configuration error**:
```bash
sudo nginx -t
# Check error message
# Verify certificate paths in /etc/nginx/sites-available/jumpserver-mtls
```

**4. Redis connection failed**:
```bash
sudo systemctl start redis-server
redis-cli ping  # Should return: PONG
```

**5. PostgreSQL connection error**:
```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Test connection
PGPASSWORD=jsroot psql -h 127.0.0.1 -U jumpserver -d jumpserver
```

**6. Django migrations error**:
```bash
cd apps
python manage.py makemigrations pki blockchain
python manage.py migrate
```

See **[DEPENDENCIES.md](DEPENDENCIES.md)** for complete troubleshooting guide.

---

## 🎯 Architecture

```
┌─────────────┐
│   Browser   │ (with mTLS certificate)
│   + Cert    │
└──────┬──────┘
       │ HTTPS + mTLS
       ↓
┌─────────────┐
│    nginx    │ (verify client certificate)
│   (443)     │
└──────┬──────┘
       │ HTTP
       ↓
┌─────────────┐
│  JumpServer │ (Django)
│   (8080)    │ ┌───────────┐  ┌──────────┐  ┌────────┐
│             │→│  PKI App  │→│Blockchain│→│  IPFS  │
│             │ │(Internal  │ │  App     │ │ (Mock) │
│             │ │   CA)     │ │ (Mock    │ └────────┘
│             │ └───────────┘ │  Fabric) │
└─────────────┘               └──────────┘
       │
       ↓
┌─────────────┐
│ PostgreSQL  │ jumpserver@localhost:5432/jumpserver
│  Database   │ (encrypted certificates, investigations, evidence)
└─────────────┘
```

---

## 📝 License

Based on JumpServer (GPL v3). See official JumpServer repository.

---

## 🆘 Support

- **Setup Issues**: See [SETUP.md](SETUP.md)
- **Dependencies**: See [DEPENDENCIES.md](DEPENDENCIES.md)
- **mTLS Testing**: See [MTLS_TESTING.md](MTLS_TESTING.md)
- **Code Changes**: See [MODIFICATIONS.md](MODIFICATIONS.md)

---

## ✅ What's Included

- ✅ Complete JumpServer v4.0 codebase
- ✅ PKI app (13 Python files)
- ✅ Blockchain app (16 Python files)
- ✅ Mock Fabric client (testing without real blockchain)
- ✅ Mock IPFS client (testing without real IPFS)
- ✅ nginx mTLS configuration
- ✅ 3 blockchain roles (Investigator, Auditor, Court)
- ✅ Automatic certificate renewal (Celery)
- ✅ Complete documentation (5 guides)
- ✅ One-command setup script

---

**Ready to test!** Just run `./setup.sh` 🚀
