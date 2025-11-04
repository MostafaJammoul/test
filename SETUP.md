# JumpServer Blockchain Chain of Custody - Setup Guide

Complete guide for setting up and testing the blockchain chain-of-custody system on Ubuntu.

---

## Quick Start (Automated)

```bash
# 1. Make script executable
chmod +x setup.sh

# 2. Run setup script (handles everything)
./setup.sh

# The script will:
# - Install system dependencies
# - Create virtual environment
# - Install Python packages
# - Initialize database and PKI
# - Create superuser (you'll be prompted)
# - Start development server
```

**Done!** Access at http://localhost:8080

---

## Manual Setup (Step-by-Step)

### 1. Prerequisites

**Ubuntu 20.04+ with Python 3.11+**

```bash
# Install Python 3.11
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3.11-dev

# Verify installation
python3.11 --version
```

### 2. Install System Dependencies

```bash
sudo apt update
sudo apt install -y \
    build-essential \
    git \
    libpq-dev \
    libmysqlclient-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    libffi-dev \
    libjpeg-dev \
    libxml2-dev \
    libxslt1-dev \
    libz-dev \
    pkg-config \
    redis-server \
    gettext
```

### 3. Start Redis

```bash
# Start and enable Redis
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Test connection
redis-cli ping  # Should return: PONG
```

### 4. Create Virtual Environment

```bash
cd truefypjs

# Create venv
python3.11 -m venv venv

# Activate venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip setuptools wheel
```

### 5. Install Python Dependencies

```bash
# Install from pyproject.toml (takes 5-10 minutes)
pip install -e .

# This installs:
# - Django 4.1.13
# - DRF 3.14.0
# - Celery 5.3.1
# - Hyperledger Fabric SDK (git+https://github.com/hyperledger/fabric-sdk-py.git)
# - IPFS HTTP Client
# - All JumpServer dependencies
```

### 6. Create Data Directories

```bash
mkdir -p data/logs
mkdir -p data/media
mkdir -p data/static
mkdir -p data/certs/pki     # PKI certificates
mkdir -p data/certs/mtls    # mTLS exported certificates
mkdir -p data/uploads       # Evidence files (mock IPFS storage)
```

### 7. Configure Application

**Edit config.yml** (optional - defaults are fine for testing):

```yaml
# Main config (already configured)
DB_ENGINE: sqlite3
DB_NAME: data/db.sqlite3
REDIS_HOST: 127.0.0.1
REDIS_PORT: 6379

# Blockchain config (mock mode enabled by default)
BLOCKCHAIN_ENABLED: false
BLOCKCHAIN_USE_MOCK: true  # ✓ Test without real Fabric
IPFS_USE_MOCK: true         # ✓ Test without real IPFS
PKI_ENABLED: true           # ✓ Internal CA enabled
MTLS_ENABLED: false         # Enable after nginx setup
```

### 8. Generate Secrets (if needed)

```bash
# Generate SECRET_KEY
cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*()_+' | head -c 50

# Generate BOOTSTRAP_TOKEN
cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 40

# Update config.yml with generated values
```

### 9. Create Database Migrations

```bash
# Create migrations for new apps
python manage.py makemigrations pki
python manage.py makemigrations blockchain

# Create any other migrations
python manage.py makemigrations
```

### 10. Run Migrations

```bash
# Apply all migrations
python manage.py migrate

# This creates:
# - Default JumpServer tables (users, assets, perms, etc.)
# - pki_certificateauthority, pki_certificate
# - blockchain_investigation, blockchain_evidence, blockchain_transaction
```

### 11. Initialize PKI (Internal CA)

```bash
# Initialize Internal Certificate Authority
python manage.py init_pki

# This creates:
# - Self-signed CA certificate (valid 10 years)
# - CA private key (encrypted in database)
# - Stored in: pki_certificateauthority table
```

### 12. Sync Builtin Roles

```bash
# Sync all roles (including blockchain roles)
python manage.py sync_role

# This creates:
# - SystemAdmin, SystemUser, SystemAuditor
# - BlockchainInvestigator (ID: 8)
# - BlockchainAuditor (ID: 9)
# - BlockchainCourt (ID: A)
```

### 13. Create Superuser

```bash
python manage.py createsuperuser

# Enter:
# - Username: admin
# - Email: admin@example.com
# - Password: (choose strong password)
```

### 14. Collect Static Files

```bash
python manage.py collectstatic --noinput

# Collects static files to: data/static/
```

### 15. Start Development Server

```bash
python manage.py runserver 0.0.0.0:8080

# Access at: http://localhost:8080
# Login with superuser credentials
```

---

## Certificate Storage Locations

### Database Storage (Primary)

**All certificates are stored encrypted in the database:**

| Table | Contents | Location |
|-------|----------|----------|
| `pki_certificateauthority` | CA certificate + private key (encrypted) | `data/db.sqlite3` |
| `pki_certificate` | User certificates + private keys (encrypted) | `data/db.sqlite3` |

**View certificates:**

```bash
# Django shell
python manage.py shell

# Python
from pki.models import CertificateAuthority, Certificate
ca = CertificateAuthority.objects.first()
print(f"CA: {ca.common_name}, Valid until: {ca.valid_until}")

certs = Certificate.objects.all()
for cert in certs:
    print(f"User: {cert.user.username}, Serial: {cert.serial_number}")
```

### Filesystem Export (For nginx mTLS)

**Certificates are exported to filesystem for nginx:**

```bash
# Export CA certificate (for nginx client verification)
python manage.py export_ca_cert --output data/certs/mtls/internal-ca.crt

# Export CRL (Certificate Revocation List)
python manage.py export_crl --output data/certs/mtls/internal-ca.crl

# Issue user certificate (P12 format for browser import)
python manage.py issue_user_cert \
    --username admin \
    --output data/certs/pki/admin.p12 \
    --password "changeme"
```

**File locations:**

```
data/
├── certs/
│   ├── mtls/              # For nginx
│   │   ├── internal-ca.crt      # CA cert (public)
│   │   └── internal-ca.crl      # Revocation list
│   └── pki/               # For users
│       ├── admin.p12            # User certificate (PKCS#12)
│       └── investigator.p12
├── db.sqlite3             # Database with encrypted certs
└── uploads/               # Mock IPFS evidence storage
```

---

## Testing Blockchain Features (Mock Mode)

### 1. Create Blockchain User

**Via Django Admin** (http://localhost:8080/admin):

1. Navigate to **Users → Add User**
2. Create user: `investigator`
3. Assign role: **BlockchainInvestigator**
4. Save

**Via API**:

```bash
curl -X POST http://localhost:8080/api/v1/users/users/ \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "investigator",
    "name": "Test Investigator",
    "email": "investigator@example.com",
    "role": "8"  # BlockchainInvestigator
  }'
```

### 2. Create Investigation

**Via API**:

```bash
curl -X POST http://localhost:8080/api/v1/blockchain/investigations/ \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Investigation",
    "description": "Testing blockchain chain of custody",
    "case_number": "CASE-2025-001"
  }'
```

**Response**:

```json
{
  "id": "uuid",
  "title": "Test Investigation",
  "status": "active",
  "chain_type": "hot",
  "created_at": "2025-11-04T12:00:00Z",
  "blockchain_tx_hash": "mock_tx_abc123"  // Mock transaction
}
```

### 3. Upload Evidence

**Via API**:

```bash
curl -X POST http://localhost:8080/api/v1/blockchain/evidence/ \
  -H "Authorization: Bearer <token>" \
  -F "investigation=<investigation_id>" \
  -F "file=@evidence.jpg" \
  -F "description=Surveillance photo" \
  -F "evidence_type=photo"
```

**What happens (Mock Mode)**:

1. File uploaded to `data/uploads/<hash>`
2. Mock IPFS returns CID: `QmMockHash123...`
3. Mock Fabric records transaction: `mock_tx_def456`
4. Database records:
   - `blockchain_evidence`: File metadata + IPFS CID
   - `blockchain_transaction`: Blockchain tx hash + block number

### 4. View Evidence Chain

**Via API**:

```bash
curl http://localhost:8080/api/v1/blockchain/investigations/<id>/evidence/ \
  -H "Authorization: Bearer <token>"
```

**Response**:

```json
{
  "investigation": "Test Investigation",
  "evidence": [
    {
      "id": "uuid",
      "file_name": "evidence.jpg",
      "ipfs_cid": "QmMockHash123...",
      "blockchain_tx_hash": "mock_tx_def456",
      "chain_of_custody": [
        {
          "timestamp": "2025-11-04T12:00:00Z",
          "action": "uploaded",
          "user": "investigator",
          "tx_hash": "mock_tx_def456"
        }
      ]
    }
  ]
}
```

### 5. Archive Investigation (Move to Cold Chain)

**Via API**:

```bash
curl -X POST http://localhost:8080/api/v1/blockchain/investigations/<id>/archive/ \
  -H "Authorization: Bearer <token>"
```

**What happens**:

1. Investigation status → `archived`
2. Mock Fabric moves data from `hot-chain` → `cold-chain`
3. Evidence becomes read-only (immutable)

---

## Testing mTLS Authentication

### 1. Issue User Certificate

```bash
# Issue certificate for user
python manage.py issue_user_cert \
    --username admin \
    --output admin.p12 \
    --password "adminpass"

# Output:
# ✓ Certificate issued
# ✓ Saved to: admin.p12
# ✓ Import this file into your browser
```

### 2. Export CA Certificate for nginx

```bash
# Export CA cert (nginx needs this to verify client certs)
python manage.py export_ca_cert --output data/certs/mtls/internal-ca.crt

# Export CRL (optional but recommended)
python manage.py export_crl --output data/certs/mtls/internal-ca.crl
```

### 3. Configure nginx

```bash
# Copy example config
sudo cp config/nginx-mtls.conf.example /etc/nginx/sites-available/jumpserver

# Edit config
sudo nano /etc/nginx/sites-available/jumpserver

# Update paths:
# - ssl_client_certificate: /path/to/data/certs/mtls/internal-ca.crt
# - ssl_crl: /path/to/data/certs/mtls/internal-ca.crl

# Enable site
sudo ln -s /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/

# Test config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### 4. Enable mTLS in JumpServer

**Edit config.yml**:

```yaml
MTLS_ENABLED: true           # Enable mTLS authentication
MTLS_REQUIRED: false         # Optional: enforce mTLS for all requests
```

**Restart JumpServer**:

```bash
# Stop current server (Ctrl+C)

# Restart
python manage.py runserver 0.0.0.0:8080
```

### 5. Import Certificate in Browser

**Firefox**:
1. Settings → Privacy & Security → Certificates
2. View Certificates → Your Certificates → Import
3. Select `admin.p12`
4. Enter password: `adminpass`

**Chrome**:
1. Settings → Privacy and security → Security
2. Manage certificates → Your certificates → Import
3. Select `admin.p12`
4. Enter password: `adminpass`

### 6. Test mTLS Connection

**Access via nginx** (assuming nginx listens on 443):

```bash
# Without certificate (should fail)
curl https://localhost/api/health/
# Expected: 400 Bad Request (No required SSL certificate was sent)

# With certificate
curl https://localhost/api/health/ \
    --cert admin.p12 \
    --cert-type P12 \
    --pass adminpass
# Expected: 200 OK
```

**Browser test**:
1. Visit: https://localhost (or your domain)
2. Browser prompts to select certificate
3. Select the imported admin certificate
4. You're automatically logged in (no password required)

### 7. Verify mTLS in Logs

**Check nginx logs**:

```bash
tail -f /var/log/nginx/jumpserver-mtls.log

# Should show:
# cert_verify=SUCCESS cert_dn="CN=admin,OU=Users,O=JumpServer,L=San Francisco,ST=California,C=US"
```

**Check Django logs**:

```bash
tail -f data/logs/jumpserver.log

# Should show:
# [INFO] mTLS authentication successful for user: admin
# [INFO] Certificate serial: 1234567890
```

---

## Blockchain Mock Client Behavior

### Mock Fabric Client (`apps/blockchain/clients/fabric_client_mock.py`)

**Simulates Hyperledger Fabric without actual blockchain:**

- **In-memory ledger**: Stores transactions in Python dict
- **Transaction IDs**: Generated as `mock_tx_<random>`
- **Block numbers**: Incremental counter
- **Channels**: Separate hot-chain and cold-chain dicts
- **Persistence**: None (resets on restart)

**Example transaction**:

```python
{
    "tx_id": "mock_tx_a1b2c3d4",
    "block_number": 42,
    "timestamp": "2025-11-04T12:00:00Z",
    "chaincode": "evidence-chaincode",
    "function": "createEvidence",
    "args": ["evidence_id", "ipfs_cid", "hash"]
}
```

### Mock IPFS Client (`apps/blockchain/clients/ipfs_client_mock.py`)

**Simulates IPFS without actual distributed storage:**

- **Local storage**: Saves files to `data/uploads/`
- **CID generation**: `QmMock<sha256_first_32_chars>`
- **File retrieval**: Reads from local filesystem
- **Pinning**: No-op (always returns success)

**Example CID**:

```
QmMockAbc123Def456Ghi789...
```

---

## Troubleshooting

### Error: `ModuleNotFoundError: No module named 'pki'`

**Solution**:

```bash
# Ensure you're in venv
source venv/bin/activate

# Reinstall in development mode
pip install -e .
```

### Error: `django.db.utils.OperationalError: no such table: pki_certificateauthority`

**Solution**:

```bash
# Create and run migrations
python manage.py makemigrations pki blockchain
python manage.py migrate
```

### Error: Redis connection failed

**Solution**:

```bash
# Check Redis status
sudo systemctl status redis-server

# Start Redis
sudo systemctl start redis-server

# Test connection
redis-cli ping  # Should return: PONG
```

### Error: `fabric-sdk-py` installation fails

**Solution**:

```bash
# Install additional dependencies
sudo apt install -y build-essential libssl-dev libffi-dev python3.11-dev

# Retry installation
pip install 'git+https://github.com/hyperledger/fabric-sdk-py.git'
```

### Error: Certificate verification fails in browser

**Solution**:

```bash
# Check certificate is valid
openssl pkcs12 -in admin.p12 -passin pass:adminpass -nokeys | openssl x509 -text

# Verify CA cert is correct
python manage.py shell
>>> from pki.models import CertificateAuthority
>>> ca = CertificateAuthority.objects.first()
>>> print(ca.certificate_pem)

# Re-export CA cert
python manage.py export_ca_cert --output data/certs/mtls/internal-ca.crt --force

# Reload nginx
sudo nginx -s reload
```

### Error: mTLS authentication fails even with valid certificate

**Solution**:

1. **Check nginx headers are passed**:

```nginx
# In nginx config
proxy_set_header X-SSL-Client-Cert $ssl_client_cert;
proxy_set_header X-SSL-Client-DN $ssl_client_s_dn;
proxy_set_header X-SSL-Client-Verify $ssl_client_verify;
```

2. **Check Django receives headers**:

```python
# In Django view
print(request.META.get('HTTP_X_SSL_CLIENT_DN'))
```

3. **Check MTLS_ENABLED in config.yml**:

```yaml
MTLS_ENABLED: true
```

---

## Next Steps

### Production Deployment

1. **Use PostgreSQL instead of SQLite**:

```yaml
# config.yml
DB_ENGINE: postgresql
DB_HOST: localhost
DB_PORT: 5432
DB_NAME: jumpserver
DB_USER: jumpserver
DB_PASSWORD: <strong_password>
```

2. **Deploy Real Hyperledger Fabric**:

```bash
# Clone fabric-samples
git clone https://github.com/hyperledger/fabric-samples.git
cd fabric-samples/test-network

# Start network
./network.sh up createChannel -c hot-chain
./network.sh up createChannel -c cold-chain

# Deploy chaincode
./network.sh deployCC -ccn evidence -ccp ../chaincode/evidence

# Update config.yml
BLOCKCHAIN_ENABLED: true
BLOCKCHAIN_USE_MOCK: false
```

3. **Deploy IPFS Node**:

```bash
# Install IPFS
wget https://dist.ipfs.io/go-ipfs/v0.28.0/go-ipfs_v0.28.0_linux-amd64.tar.gz
tar -xvzf go-ipfs_v0.28.0_linux-amd64.tar.gz
cd go-ipfs
sudo bash install.sh

# Initialize IPFS
ipfs init

# Start daemon
ipfs daemon

# Update config.yml
IPFS_ENABLED: true
IPFS_USE_MOCK: false
```

4. **Use Gunicorn + Supervisor**:

```bash
# Install gunicorn
pip install gunicorn

# Create supervisor config
sudo nano /etc/supervisor/conf.d/jumpserver.conf
```

5. **Configure SSL with Let's Encrypt**:

```bash
# Install certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d jumpserver.example.com
```

---

## Support

- **Documentation**: See [MODIFICATIONS.md](MODIFICATIONS.md)
- **nginx mTLS Setup**: See [config/nginx-mtls.conf.example](config/nginx-mtls.conf.example)
- **Blockchain Config**: See [config/blockchain.yml.example](config/blockchain.yml.example)

---

**End of SETUP.md**
