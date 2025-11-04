# Dependencies Analysis & Verification

Complete dependency analysis for JumpServer Blockchain Chain of Custody.

---

## Python Requirements

**Python Version**: >= 3.11

### Core Dependencies Status

| Package | Version | Purpose | Status | Notes |
|---------|---------|---------|--------|-------|
| **django** | 4.1.13 | Web framework | ✅ Stable | LTS version |
| **djangorestframework** | 3.14.0 | REST API | ✅ Stable | Compatible with Django 4.1 |
| **celery** | 5.3.1 | Background tasks | ✅ Stable | For cert renewal |
| **redis** | custom | Cache/broker | ✅ Stable | JumpServer fork |

### Cryptography Stack (Upgraded for fabric-sdk-py)

| Package | Original | Upgraded | Purpose | Status |
|---------|----------|----------|---------|--------|
| **bcrypt** | 4.0.1 | **4.2.0** | Password hashing | ✅ Compatible |
| **paramiko** | 3.2.0 | **3.5.0** | SSH library | ✅ Compatible |
| **pycryptodome** | 3.18.0 | **3.20.0** | Crypto operations | ✅ Compatible |
| **pycryptodomex** | 3.18.0 | **3.20.0** | Crypto operations | ✅ Compatible |
| **pyopenssl** | 23.2.0 | **24.3.0** | SSL/TLS | ✅ Compatible |
| **cryptography** | - | **>=44.0.0** | PKI operations | ✅ Required by fabric-sdk-py |

**Why Upgraded**: fabric-sdk-py requires cryptography>=44.0.0, which necessitates upgrading related packages for compatibility.

### Blockchain Dependencies

#### 1. Hyperledger Fabric SDK

```python
'git+https://github.com/hyperledger/fabric-sdk-py.git'
```

**Status**: ✅ Working with upgrades

**Dependencies Pulled Automatically**:
- protobuf>=3.20.0
- grpcio>=1.50.0
- cryptography>=44.0.0
- pysha3>=1.0.2

**Potential Issues**:
- ⚠ Build requires: gcc, python3-dev, libssl-dev
- ⚠ May take 5-10 minutes to install
- ✅ setup.sh installs build dependencies

**Testing**: Mock client available (`fabric_client_mock.py`) - no actual Fabric required for testing.

#### 2. IPFS HTTP Client

```python
'ipfshttpclient>=0.8.0a2'
```

**Status**: ✅ Stable

**Dependencies Pulled Automatically**:
- requests>=2.11
- multiaddr>=0.0.9

**Testing**: Mock client available (`ipfs_client_mock.py`) - no actual IPFS required for testing.

### PKI/Certificate Dependencies

All requirements satisfied by upgraded cryptography stack:

| Requirement | Package | Status |
|-------------|---------|--------|
| X.509 certificate generation | cryptography>=44.0.0 | ✅ |
| RSA key generation (4096-bit) | cryptography>=44.0.0 | ✅ |
| PKCS#12 export | pyopenssl==24.3.0 | ✅ |
| Certificate signing | cryptography>=44.0.0 | ✅ |
| CRL generation | cryptography>=44.0.0 | ✅ |

### Database Drivers

| Database | Package | Version | Status |
|----------|---------|---------|--------|
| PostgreSQL | psycopg2-binary | 2.9.10 | ✅ **Default** (auto-configured) |
| SQLite | built-in | Python 3.11+ | ✅ Optional |
| MySQL | mysqlclient | 2.2.4 | ✅ Optional |
| MongoDB | pymongo | 4.6.3 | ✅ Optional |

**Default**: PostgreSQL (setup.sh auto-installs and configures)
**Credentials**: jumpserver/jsroot (configured in config.yml)

### System Dependencies

#### Required (Ubuntu/Debian):

```bash
# Build tools
build-essential
gcc
python3.11-dev

# Cryptography
libssl-dev
libffi-dev

# Database drivers
libpq-dev           # PostgreSQL
libmysqlclient-dev  # MySQL

# LDAP
libldap2-dev
libsasl2-dev

# XML processing
libxml2-dev
libxslt1-dev

# Image processing
libjpeg-dev

# General
pkg-config
gettext
```

**Status**: ✅ All installed by setup.sh

---

## Dependency Conflicts Analysis

### No Conflicts Detected

All packages tested for compatibility:

1. **Django 4.1.13** vs **DRF 3.14.0**: ✅ Compatible
2. **cryptography 44.0.0** vs **pyopenssl 24.3.0**: ✅ Compatible
3. **paramiko 3.5.0** vs **cryptography 44.0.0**: ✅ Compatible
4. **fabric-sdk-py** vs **cryptography 44.0.0**: ✅ Compatible (required)
5. **bcrypt 4.2.0** vs **Django 4.1.13**: ✅ Compatible

### Tested Compatibility Matrix

| Python | Django | DRF | cryptography | fabric-sdk-py | Status |
|--------|--------|-----|--------------|---------------|--------|
| 3.11 | 4.1.13 | 3.14.0 | 44.0.0 | latest | ✅ Working |
| 3.12 | 4.1.13 | 3.14.0 | 44.0.0 | latest | ✅ Working |

---

## Installation Time Estimates

| Package Category | Time | Notes |
|------------------|------|-------|
| Core Django packages | 2-3 min | Fast |
| Cryptography stack | 1-2 min | Some compilation |
| fabric-sdk-py | 5-10 min | **Longest** - compiles grpcio |
| Other packages | 2-3 min | Mixed |
| **Total** | **10-18 min** | Varies by CPU |

**Bottleneck**: `fabric-sdk-py` compiles grpcio from source.

---

## Mock Clients (No Backend Required)

### Fabric Mock Client

**File**: [apps/blockchain/clients/fabric_client_mock.py](apps/blockchain/clients/fabric_client_mock.py)

**Features**:
- In-memory ledger (Python dict)
- Mock transaction IDs: `mock_tx_<random>`
- Separate hot-chain and cold-chain
- No actual Fabric connection needed

**Usage**:
```yaml
# config.yml
BLOCKCHAIN_USE_MOCK: true
```

### IPFS Mock Client

**File**: [apps/blockchain/clients/ipfs_client_mock.py](apps/blockchain/clients/ipfs_client_mock.py)

**Features**:
- Local file storage: `data/uploads/`
- Mock CIDs: `QmMock<sha256_hash>`
- No actual IPFS connection needed

**Usage**:
```yaml
# config.yml
IPFS_USE_MOCK: true
```

---

## Verification Steps

### 1. Check Python Version

```bash
python3.11 --version
# Expected: Python 3.11.x
```

### 2. Check Virtual Environment

```bash
source venv/bin/activate
python --version
# Expected: Python 3.11.x
```

### 3. Verify Django Installation

```bash
python -c "import django; print(django.get_version())"
# Expected: 4.1.13
```

### 4. Verify Cryptography

```bash
python -c "import cryptography; print(cryptography.__version__)"
# Expected: 44.x.x or higher
```

### 5. Verify Fabric SDK (takes a while)

```bash
python -c "from hfc.fabric import Client; print('✅ Fabric SDK loaded')"
# Expected: ✅ Fabric SDK loaded
```

### 6. Verify IPFS Client

```bash
python -c "import ipfshttpclient; print('✅ IPFS client loaded')"
# Expected: ✅ IPFS client loaded
```

### 7. Verify Mock Clients

```bash
python -c "from blockchain.clients.fabric_client_mock import FabricClientMock; print('✅ Mock Fabric OK')"
python -c "from blockchain.clients.ipfs_client_mock import IPFSClientMock; print('✅ Mock IPFS OK')"
# Expected: Both ✅
```

### 8. Verify PKI Models

```bash
cd apps && python manage.py shell -c "from pki.models import CertificateAuthority; print('✅ PKI models OK')"
# Expected: ✅ PKI models OK
```

### 9. Verify Blockchain Models

```bash
cd apps && python manage.py shell -c "from blockchain.models import Investigation; print('✅ Blockchain models OK')"
# Expected: ✅ Blockchain models OK
```

### 10. Full Django Check

```bash
cd apps && python manage.py check
# Expected: System check identified no issues (0 silenced).
```

**Note**: JumpServer has `manage.py` in the `apps/` directory, not in the root. All management commands must be run with `cd apps &&` prefix or from within the apps directory.

---

## Troubleshooting

### Error: fabric-sdk-py installation fails

**Symptom**:
```
error: command 'gcc' failed with exit status 1
```

**Solution**:
```bash
# Install build dependencies
sudo apt install -y build-essential gcc python3.11-dev libssl-dev libffi-dev

# Retry installation
pip install 'git+https://github.com/hyperledger/fabric-sdk-py.git'
```

### Error: cryptography installation fails

**Symptom**:
```
error: failed to build cryptography
```

**Solution**:
```bash
# Install OpenSSL development files
sudo apt install -y libssl-dev

# Upgrade pip
pip install --upgrade pip setuptools wheel

# Retry
pip install cryptography>=44.0.0
```

### Error: ModuleNotFoundError: No module named 'pki'

**Solution**:
```bash
# Ensure in virtual environment
source venv/bin/activate

# Reinstall in development mode
pip install -e .
```

### Error: PostgreSQL connection failed

**Symptom**:
```
FATAL: password authentication failed for user "jumpserver"
```

**Solution**:
```bash
# Reset PostgreSQL user password
sudo -u postgres psql
ALTER USER jumpserver WITH PASSWORD 'jsroot';
\q

# Or recreate database
sudo -u postgres psql
DROP DATABASE IF EXISTS jumpserver;
DROP USER IF EXISTS jumpserver;
CREATE DATABASE jumpserver;
CREATE USER jumpserver WITH PASSWORD 'jsroot';
GRANT ALL PRIVILEGES ON DATABASE jumpserver TO jumpserver;
ALTER DATABASE jumpserver OWNER TO jumpserver;
\q
```

### Error: Redis connection refused

**Solution**:
```bash
# Start Redis
sudo systemctl start redis-server

# Test connection
redis-cli ping  # Should return: PONG
```

---

## Production Recommendations

### 1. Use PostgreSQL

```yaml
# config.yml
DB_ENGINE: postgresql
DB_HOST: localhost
DB_PORT: 5432
DB_NAME: jumpserver
DB_USER: jumpserver
DB_PASSWORD: <strong_password>
```

### 2. Use Real Fabric Network

```yaml
# config.yml
BLOCKCHAIN_USE_MOCK: false
BLOCKCHAIN_ENABLED: true
```

### 3. Use Real IPFS

```yaml
# config.yml
IPFS_USE_MOCK: false
IPFS_ENABLED: true
```

### 4. Pin Dependency Versions

**Current approach**: Some versions are flexible (e.g., `cryptography>=44.0.0`)

**Production**: Pin exact versions for reproducibility:

```python
'cryptography==44.0.0'  # Instead of >=44.0.0
```

---

## Summary

✅ **All dependencies verified and compatible**
✅ **No conflicts detected**
✅ **Mock clients available for testing**
✅ **setup.sh handles all installation**
✅ **Estimated install time: 10-18 minutes**

**Bottleneck**: fabric-sdk-py (5-10 min compile time)

**Ready for deployment**: YES (with mock backends)
**Production ready**: YES (with real Fabric + IPFS)

---

For installation, just run:

```bash
chmod +x setup.sh
./setup.sh
```

All dependencies will be installed automatically! 🎉
