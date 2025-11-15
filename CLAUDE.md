# CLAUDE.md - AI Assistant Guide for JumpServer Blockchain CoC System

**Last Updated**: 2025-11-15
**Project**: JumpServer Blockchain Chain of Custody System
**Version**: Based on JumpServer v4.0

---

## 🎯 Project Overview

### What This System Does

This is an **enterprise-grade blockchain evidence management system** for law enforcement and legal investigations. It provides:

- **Immutable evidence tracking** using Hyperledger Fabric blockchain
- **Chain of custody verification** for legal evidence handling
- **Certificate-based mTLS authentication** with multi-factor authentication (MFA)
- **Anonymous evidence submission** with court-authorized GUID resolution
- **Distributed file storage** via IPFS for large evidence files
- **Hot/Cold chain architecture** for active investigations vs. archived cases
- **Role-based access control** (Investigator, Auditor, Court roles)

### Target Users

- Law enforcement agencies
- Forensic investigators
- Legal teams and prosecutors
- Court systems
- Evidence custodians
- System administrators

---

## 🏗️ Architecture Overview

### Technology Stack

**Backend**:
- Python 3.11+ with Django 4.1.13
- Django REST Framework 3.14.0
- PostgreSQL 12+ (primary database)
- Redis 5.x+ (cache + message broker)
- Celery 5.3.1 (async tasks)
- Gunicorn 23.0.0 (WSGI) / Daphne 4.0.0 (ASGI)

**Blockchain & Storage**:
- Hyperledger Fabric (via fabric-sdk-py)
- IPFS (via ipfshttpclient)
- Mock clients available for development

**Security**:
- nginx with mTLS (client certificate authentication)
- Internal PKI/CA system (pyOpenSSL, cryptography)
- TOTP-based MFA (pyotp)
- FIDO2/WebAuthn support (fido2)

**Frontend**:
- React 18.2.0 with Vite 5.0.8
- React Router DOM 6.20.0
- Axios 1.6.2 for API calls
- Tailwind CSS 3.3.6
- Recharts 2.10.3 for visualizations

### Multi-Tier Storage Architecture

```
┌─────────────┐
│ PostgreSQL  │ ← Metadata, relationships, mutable data
└─────────────┘
       ↓
┌─────────────┐
│ Blockchain  │ ← Immutable evidence hashes, audit trail
└─────────────┘
       ↓
┌─────────────┐
│    IPFS     │ ← Large files (disk images, videos, documents)
└─────────────┘
```

---

## 📁 Critical Directory Structure

```
/home/user/test/
├── apps/                              # Django backend
│   ├── jumpserver/                    # Core settings & config
│   │   ├── settings/
│   │   │   ├── base.py               # ✏️ MODIFIED - Base config
│   │   │   ├── auth.py               # Authentication settings
│   │   │   └── logging.py            # Logging configuration
│   │   └── urls.py                   # Main URL routing
│   │
│   ├── blockchain/                    # ✨ NEW - Evidence chain app
│   │   ├── models.py                 # Investigation, Evidence, BlockchainTransaction
│   │   ├── api/
│   │   │   ├── views.py              # 975 lines - API endpoints
│   │   │   ├── serializers.py        # 188 lines - Data validation
│   │   │   └── urls.py               # URL routing
│   │   ├── clients/
│   │   │   ├── fabric_client.py      # Real Hyperledger Fabric client
│   │   │   ├── fabric_client_mock.py # Mock for development
│   │   │   ├── ipfs_client.py        # Real IPFS client
│   │   │   └── ipfs_client_mock.py   # Mock for development
│   │   ├── services/
│   │   │   ├── archive_service.py    # Hot→Cold chain migration
│   │   │   └── guid_resolver.py      # Anonymous GUID resolution
│   │   └── migrations/               # Database schema
│   │
│   ├── pki/                           # ✨ NEW - Internal PKI/CA
│   │   ├── models.py                 # 184 lines - CA & Certificate models
│   │   ├── ca_manager.py             # CA operations
│   │   ├── tasks.py                  # Celery auto-renewal tasks
│   │   ├── api/                      # 815 lines - REST API
│   │   └── management/commands/      # Django CLI commands
│   │       ├── init_pki.py           # Initialize CA
│   │       ├── issue_user_cert.py    # Issue user certificates
│   │       ├── export_ca_cert.py     # Export CA for nginx
│   │       └── export_crl.py         # Certificate revocation list
│   │
│   ├── rbac/
│   │   └── builtin.py                # ✏️ MODIFIED - Added blockchain roles
│   │
│   └── [standard JumpServer apps]/   # users, assets, perms, etc.
│
├── frontend/                          # React SPA
│   ├── src/
│   │   ├── components/
│   │   │   ├── investigation/        # Investigation UI components
│   │   │   ├── admin/                # Admin management
│   │   │   ├── layout/               # Navbar, layout components
│   │   │   └── common/               # Reusable components
│   │   ├── pages/
│   │   │   ├── dashboard/            # Role-based dashboards
│   │   │   │   ├── InvestigatorDashboard.jsx
│   │   │   │   ├── AuditorDashboard.jsx
│   │   │   │   ├── CourtDashboard.jsx
│   │   │   │   └── InvestigationDetailPage.jsx
│   │   │   ├── admin/                # Admin dashboard
│   │   │   ├── Login.jsx             # Password authentication
│   │   │   ├── MFASetup.jsx          # TOTP enrollment
│   │   │   └── MFAChallenge.jsx      # MFA verification
│   │   ├── contexts/
│   │   │   ├── AuthContext.jsx       # Auth state management
│   │   │   └── ToastContext.jsx      # Toast notifications
│   │   ├── services/
│   │   │   └── api.js                # Axios HTTP client
│   │   └── App.jsx                   # Route configuration
│   ├── package.json
│   └── vite.config.js
│
├── config/                            # Configuration examples
│   ├── blockchain.yml.example        # Fabric network config
│   └── nginx-mtls.conf.example       # mTLS reverse proxy
│
├── data/                              # Runtime data (gitignored)
│   ├── certs/
│   │   ├── mtls/                     # nginx CA certificates
│   │   └── pki/                      # User certificates (.p12)
│   ├── logs/                         # Application logs
│   └── uploads/                      # Mock IPFS storage
│
├── docs/                              # 81 documentation files
│
├── config.yml                        # ✏️ MODIFIED - Main configuration
├── pyproject.toml                    # ✏️ MODIFIED - Python dependencies
└── setup.sh                          # 1,245 lines - Automated setup
```

---

## 🔑 Key Database Models

### Blockchain App Models (`apps/blockchain/models.py`)

**1. Investigation**
```python
class Investigation(models.Model):
    guid = UUIDField(default=uuid4, editable=False, unique=True)
    case_number = CharField(max_length=100, unique=True)
    title = CharField(max_length=255)
    description = TextField()
    investigator = ForeignKey(User, related_name='investigations')
    status = CharField(choices=['active', 'archived', 'closed'])
    chain_type = CharField(choices=['hot', 'cold'], default='hot')
    blockchain_id = CharField(max_length=255, blank=True)
    created_at = DateTimeField(auto_now_add=True)
    archived_at = DateTimeField(null=True, blank=True)
```

**2. Evidence**
```python
class Evidence(models.Model):
    investigation = ForeignKey(Investigation, related_name='evidence_files')
    description = TextField()
    file_name = CharField(max_length=255)
    file_hash = CharField(max_length=64)  # SHA-256
    ipfs_hash = CharField(max_length=255, blank=True)
    blockchain_hash = CharField(max_length=255, blank=True)
    submitted_by = ForeignKey(User)
    submitted_at = DateTimeField(auto_now_add=True)
    file_size = BigIntegerField()
    content_type = CharField(max_length=100)
```

**3. BlockchainTransaction**
```python
class BlockchainTransaction(models.Model):
    investigation = ForeignKey(Investigation, related_name='transactions')
    evidence = ForeignKey(Evidence, related_name='transactions', null=True)
    transaction_type = CharField(choices=['CREATE_INVESTIGATION', 'ADD_EVIDENCE', ...])
    blockchain_tx_id = CharField(max_length=255, unique=True)
    transaction_data = JSONField()
    created_at = DateTimeField(auto_now_add=True)
```

### PKI App Models (`apps/pki/models.py`)

**1. CertificateAuthority**
```python
class CertificateAuthority(models.Model):
    name = CharField(max_length=255)
    is_active = BooleanField(default=True)
    certificate = TextField()  # PEM-encoded
    private_key = TextField()  # Encrypted PEM
    valid_from = DateTimeField()
    valid_until = DateTimeField()
```

**2. Certificate**
```python
class Certificate(models.Model):
    user = ForeignKey(User, related_name='certificates')
    ca = ForeignKey(CertificateAuthority)
    serial_number = CharField(max_length=40, unique=True)
    certificate = TextField()  # PEM-encoded
    revoked = BooleanField(default=False)
    revoked_at = DateTimeField(null=True)
    issued_at = DateTimeField(auto_now_add=True)
    expires_at = DateTimeField()
```

---

## 🔐 Authentication & Authorization

### Authentication Flow

1. **Password + MFA** (username/password + TOTP)
2. **mTLS Certificate** (client certificate via nginx)
3. **Session Token** (stored in browser for API calls)

### RBAC Roles (`apps/rbac/builtin.py`)

**Blockchain-Specific Roles** (added to existing JumpServer roles):

| Role ID | Role Name | Permissions |
|---------|-----------|-------------|
| `8` | `BlockchainInvestigator` | Create investigations, submit evidence, view own cases |
| `9` | `BlockchainAuditor` | Read-only access to all investigations, view blockchain transactions |
| `A` | `BlockchainCourt` | Full read access, GUID resolution, evidence verification |

**Permission Inheritance**:
- Court role inherits Auditor permissions
- All blockchain roles inherit base User permissions

### API Authentication

**Headers Required**:
```http
Authorization: Bearer <session_token>
X-CSRFToken: <csrf_token>
```

**Frontend Implementation** (`frontend/src/services/api.js`):
```javascript
axios.interceptors.request.use(config => {
  const token = localStorage.getItem('authToken');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});
```

---

## 🛣️ API Endpoints

### Blockchain API (`/api/v1/blockchain/`)

**Investigations**:
- `GET /api/v1/blockchain/investigations/` - List investigations
- `POST /api/v1/blockchain/investigations/` - Create investigation
- `GET /api/v1/blockchain/investigations/{id}/` - Get details
- `PATCH /api/v1/blockchain/investigations/{id}/` - Update investigation
- `POST /api/v1/blockchain/investigations/{id}/archive/` - Archive investigation
- `POST /api/v1/blockchain/investigations/{id}/reopen/` - Reopen investigation

**Evidence**:
- `GET /api/v1/blockchain/evidence/` - List evidence
- `POST /api/v1/blockchain/evidence/` - Submit evidence (multipart/form-data)
- `GET /api/v1/blockchain/evidence/{id}/` - Get evidence details
- `GET /api/v1/blockchain/evidence/{id}/download/` - Download evidence file
- `POST /api/v1/blockchain/evidence/{id}/verify/` - Verify blockchain hash

**Blockchain Transactions**:
- `GET /api/v1/blockchain/transactions/` - List transactions (read-only)
- `GET /api/v1/blockchain/transactions/{id}/` - Get transaction details

**GUID Resolution** (Court role only):
- `POST /api/v1/blockchain/resolve-guid/` - Resolve anonymous GUID to case details

### PKI API (`/api/v1/pki/`)

**Certificates**:
- `GET /api/v1/pki/certificates/` - List user certificates
- `POST /api/v1/pki/certificates/issue/` - Issue new certificate
- `POST /api/v1/pki/certificates/{id}/renew/` - Renew certificate
- `POST /api/v1/pki/certificates/{id}/revoke/` - Revoke certificate
- `GET /api/v1/pki/certificates/{id}/download/` - Download .p12 file

**CA Management**:
- `GET /api/v1/pki/ca/` - Get CA details
- `GET /api/v1/pki/ca/export/` - Export CA certificate (PEM)
- `GET /api/v1/pki/ca/crl/` - Download Certificate Revocation List

---

## 🧩 Key Components & Services

### Blockchain Clients

**Real Implementation** (`apps/blockchain/clients/fabric_client.py`):
```python
class FabricClient:
    def submit_transaction(self, channel, chaincode, function, args):
        # Connects to Hyperledger Fabric network
        # Requires fabric-network.json configuration
        pass
```

**Mock Implementation** (`apps/blockchain/clients/fabric_client_mock.py`):
```python
class FabricClientMock:
    def submit_transaction(self, channel, chaincode, function, args):
        # Simulates blockchain without Fabric network
        # Returns fake transaction IDs
        # Stores transactions in memory
        pass
```

**Configuration** (`config.yml`):
```yaml
BLOCKCHAIN_USE_MOCK: true  # Use mock for development
IPFS_USE_MOCK: true        # Use local filesystem instead of IPFS
```

### Archive Service (`apps/blockchain/services/archive_service.py`)

Handles hot→cold chain migration for archived investigations:

```python
class ArchiveService:
    def archive_investigation(investigation_id):
        # 1. Verify all evidence is submitted
        # 2. Submit final blockchain transaction
        # 3. Migrate data to cold storage
        # 4. Update investigation.chain_type = 'cold'
        # 5. Set archived_at timestamp

    def reopen_investigation(investigation_id):
        # 1. Verify court authorization
        # 2. Restore from cold chain
        # 3. Update investigation.status = 'active'
        # 4. Log blockchain transaction
```

### GUID Resolver (`apps/blockchain/services/guid_resolver.py`)

Court-authorized resolution of anonymous evidence GUIDs:

```python
class GUIDResolver:
    def resolve_guid(guid, court_user):
        # 1. Verify court_user has Court role
        # 2. Look up investigation by GUID
        # 3. Log access in audit trail
        # 4. Return full case details
        # 5. Notify investigator of access
```

---

## 🚀 Development Workflow

### Initial Setup

**1. One-Command Setup**:
```bash
chmod +x setup.sh
./setup.sh  # Takes 15-20 minutes
```

This script automatically:
- Installs PostgreSQL, Redis, nginx
- Creates Python virtual environment
- Installs dependencies from `pyproject.toml`
- Runs database migrations
- Initializes PKI (creates internal CA)
- Configures nginx with mTLS
- Creates superuser account
- Issues admin certificate

**2. Manual Setup** (if setup.sh fails):
```bash
# Install system dependencies
sudo apt-get update
sudo apt-get install -y postgresql redis-server nginx python3.11 python3-pip

# Create database
sudo -u postgres createuser -s jsroot
sudo -u postgres createdb jumpserver -O jsroot
sudo -u postgres psql -c "ALTER USER jsroot WITH PASSWORD 'jsroot';"

# Python environment
python3.11 -m venv venv
source venv/bin/activate
pip install uv
uv pip install -e .

# Database migrations
cd apps
python manage.py migrate

# Initialize PKI
python manage.py init_pki
python manage.py issue_user_cert admin

# Create superuser
python manage.py createsuperuser
```

### Running the Application

**Backend** (Development):
```bash
cd apps
source ../venv/bin/activate

# Option 1: Django dev server (no HTTPS/mTLS)
python manage.py runserver 0.0.0.0:8080

# Option 2: Gunicorn (production-like)
gunicorn jumpserver.wsgi:application --bind 0.0.0.0:8080

# Option 3: All services
cd ..
./start_services.sh  # Starts Django, Celery, Redis, nginx
```

**Frontend** (Development):
```bash
cd frontend
npm install
npm run dev  # Vite dev server on http://localhost:5173
```

**Frontend** (Production Build):
```bash
cd frontend
npm run build  # Outputs to frontend/dist/
```

### Database Migrations

**Creating Migrations**:
```bash
cd apps
python manage.py makemigrations blockchain
python manage.py makemigrations pki
```

**Applying Migrations**:
```bash
python manage.py migrate
```

**Reset Database** (⚠️ DESTROYS ALL DATA):
```bash
./setup.sh  # Will prompt before purging database
```

### PKI Management

**Initialize CA**:
```bash
cd apps
python manage.py init_pki
```

**Issue User Certificate**:
```bash
python manage.py issue_user_cert <username>
# Generates: data/certs/pki/<username>.p12
# Password: (printed to console)
```

**Export CA for nginx**:
```bash
python manage.py export_ca_cert
# Outputs: data/certs/mtls/internal-ca.crt
```

**Export CRL**:
```bash
python manage.py export_crl
# Outputs: data/certs/mtls/internal-ca.crl
```

**Revoke Certificate**:
```python
# Via Django shell or API
cert = Certificate.objects.get(user__username='john')
cert.revoke()
```

### Testing

**Run Django Tests**:
```bash
cd apps
python manage.py test

# Specific app
python manage.py test blockchain
python manage.py test pki

# Specific test
python manage.py test blockchain.tests.test_api
```

**Test Scripts**:
```bash
./test_auth.sh              # Authentication flow
./test_rbac.sh              # RBAC permissions
./test_jumpserver.sh        # End-to-end tests
./diagnose_password.sh      # Password complexity
```

**Manual Testing with Mock Clients**:
```yaml
# config.yml
BLOCKCHAIN_USE_MOCK: true
IPFS_USE_MOCK: true
```

---

## 🐛 Debugging & Troubleshooting

### Common Issues

**1. Database Connection Errors**

```bash
# Error: FATAL: password authentication failed for user "jsroot"
# Fix:
sudo -u postgres psql -c "ALTER USER jsroot WITH PASSWORD 'jsroot';"

# Update config.yml:
DB_HOST: localhost
DB_PORT: 5432
DB_NAME: jumpserver
DB_USER: jsroot
DB_PASSWORD: jsroot
```

**2. Redis Connection Errors**

```bash
# Error: Error 111 connecting to localhost:6379. Connection refused.
# Fix:
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

**3. Migration Errors**

```bash
# Error: Relation "blockchain_investigation" does not exist
# Fix:
cd apps
python manage.py migrate --run-syncdb
```

**4. PKI Initialization Fails**

```bash
# Error: CA already exists
# Fix (⚠️ destroys existing certificates):
rm -rf data/certs/pki/*
cd apps
python manage.py init_pki --force
```

**5. Frontend Cannot Reach Backend**

```bash
# Error: Network Error / 404
# Fix: Check CORS settings in apps/jumpserver/settings/base.py

CORS_ALLOWED_ORIGINS = [
    "http://localhost:5173",  # Vite dev server
    "http://localhost:8080",  # Django dev server
]
```

**6. mTLS Certificate Validation Errors**

```bash
# Error: 400 No required SSL certificate was sent
# Fix:
# 1. Ensure nginx is configured correctly
sudo ln -s /etc/nginx/sites-available/jumpserver-mtls /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 2. Import certificate in browser (.p12 file from data/certs/pki/)
# 3. Set MTLS_REQUIRED: false in config.yml for development
```

### Diagnostic Scripts

```bash
./diagnose.sh               # System diagnostics
./diagnose_password.sh      # Test password complexity
```

### Logs

**Django Logs**:
```bash
tail -f data/logs/jumpserver.log
```

**Celery Logs**:
```bash
tail -f data/logs/celery.log
```

**nginx Logs**:
```bash
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

**PostgreSQL Logs**:
```bash
sudo tail -f /var/log/postgresql/postgresql-*.log
```

---

## 📝 Code Conventions & Best Practices

### Python Code Style

**Follow PEP 8** with these specifics:

```python
# Imports (alphabetical within groups)
from django.db import models
from rest_framework import viewsets

from apps.blockchain.models import Investigation
from apps.pki.ca_manager import CAManager

# Class naming
class InvestigationViewSet(viewsets.ModelViewSet):  # PascalCase

# Method naming
def archive_investigation(self, request, pk=None):  # snake_case

# Constants
MAX_EVIDENCE_SIZE = 1024 * 1024 * 100  # UPPER_SNAKE_CASE

# Type hints (encouraged)
def submit_evidence(self, evidence: Evidence) -> BlockchainTransaction:
    pass
```

### Django Model Conventions

```python
class Investigation(models.Model):
    # Fields in order:
    # 1. Primary key (if custom)
    # 2. Foreign keys
    # 3. Regular fields (alphabetical)
    # 4. Timestamps (created_at, updated_at)

    investigator = models.ForeignKey(User, related_name='investigations')
    blockchain_id = models.CharField(max_length=255, blank=True)
    case_number = models.CharField(max_length=100, unique=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['case_number']),
            models.Index(fields=['investigator', 'status']),
        ]

    def __str__(self):
        return f"{self.case_number}: {self.title}"
```

### API ViewSet Conventions

```python
class InvestigationViewSet(viewsets.ModelViewSet):
    queryset = Investigation.objects.all()
    serializer_class = InvestigationSerializer
    permission_classes = [IsAuthenticated, IsInvestigatorOrAuditor]

    def get_queryset(self):
        # Investigators see only their investigations
        # Auditors/Court see all
        user = self.request.user
        if user.has_role('BlockchainAuditor', 'BlockchainCourt'):
            return Investigation.objects.all()
        return Investigation.objects.filter(investigator=user)

    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        # Custom actions use snake_case
        investigation = self.get_object()
        service = ArchiveService()
        service.archive_investigation(investigation.id)
        return Response({'status': 'archived'})
```

### React Component Conventions

```javascript
// Component naming: PascalCase
function InvestigationCard({ investigation, onArchive }) {
  // Hooks at the top
  const [isExpanded, setIsExpanded] = useState(false);
  const navigate = useNavigate();

  // Event handlers: handleXxx
  const handleArchiveClick = () => {
    onArchive(investigation.id);
  };

  // Render
  return (
    <div className="investigation-card">
      {/* Component JSX */}
    </div>
  );
}

export default InvestigationCard;
```

### File Naming

```
Backend (Python):
- Models: singular (investigation.py, not investigations.py)
- Views: plural (views.py, viewsets.py)
- Services: suffix (archive_service.py)
- Clients: suffix (fabric_client.py)

Frontend (JavaScript):
- Components: PascalCase.jsx (InvestigationCard.jsx)
- Pages: PascalCase.jsx (InvestigatorDashboard.jsx)
- Utilities: camelCase.js (apiHelpers.js)
- Contexts: PascalCaseContext.jsx (AuthContext.jsx)
```

---

## 🔧 Configuration Files

### Main Configuration (`config.yml`)

```yaml
# Security
SECRET_KEY: "CHANGE-ME-IN-PRODUCTION"
DEBUG: false
ALLOWED_HOSTS: ['*']

# Database
DB_ENGINE: postgresql
DB_HOST: localhost
DB_PORT: 5432
DB_NAME: jumpserver
DB_USER: jsroot
DB_PASSWORD: jsroot

# Redis
REDIS_HOST: localhost
REDIS_PORT: 6379
REDIS_PASSWORD: ""

# Authentication
MTLS_REQUIRED: true  # Enforce client certificates
MFA_REQUIRED: true   # Enforce TOTP for all users

# Blockchain
BLOCKCHAIN_USE_MOCK: true   # Set to false for production
FABRIC_NETWORK_CONFIG: config/fabric-network.json
FABRIC_CHANNEL: evidence-channel
FABRIC_CHAINCODE: evidence-chaincode

# IPFS
IPFS_USE_MOCK: true  # Set to false for production
IPFS_HOST: localhost
IPFS_PORT: 5001

# PKI
PKI_CA_NAME: "Internal Certificate Authority"
PKI_CA_VALIDITY_DAYS: 3650
PKI_CERT_VALIDITY_DAYS: 365
PKI_AUTO_RENEW_DAYS: 30  # Renew certificates 30 days before expiry
```

### Blockchain Configuration (`config/blockchain.yml.example`)

```yaml
fabric:
  network:
    name: evidence-network
    channel: evidence-channel
    chaincode: evidence-chaincode
  organizations:
    - name: Org1
      mspid: Org1MSP
      peers:
        - peer0.org1.example.com:7051
      ca: ca.org1.example.com:7054
  orderers:
    - orderer.example.com:7050
```

### nginx mTLS Configuration (`config/nginx-mtls.conf.example`)

```nginx
server {
    listen 443 ssl;
    server_name jumpserver.local;

    # SSL/TLS Configuration
    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    # Client Certificate (mTLS)
    ssl_client_certificate /path/to/data/certs/mtls/internal-ca.crt;
    ssl_verify_client on;  # Enforce client certificates
    ssl_verify_depth 2;

    # CRL (Certificate Revocation List)
    ssl_crl /path/to/data/certs/mtls/internal-ca.crl;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Pass client certificate info to Django
        proxy_set_header X-SSL-Client-DN $ssl_client_s_dn;
        proxy_set_header X-SSL-Client-Verify $ssl_client_verify;
        proxy_set_header X-SSL-Client-Serial $ssl_client_serial;
    }
}
```

---

## 🚨 Security Considerations

### Critical Security Rules

1. **NEVER commit secrets to git**:
   - `config.yml` with real SECRET_KEY
   - `.p12` certificate files
   - Private keys (`.key`, `.pem`)
   - Database credentials

2. **Always use environment-specific configs**:
   - Development: `BLOCKCHAIN_USE_MOCK: true`
   - Production: `BLOCKCHAIN_USE_MOCK: false`

3. **Certificate Management**:
   - Auto-renewal enabled via Celery tasks
   - CRL regenerated on every revocation
   - nginx must reload after CRL updates

4. **Input Validation**:
   - All API inputs validated via DRF serializers
   - File uploads limited to 100MB
   - File types validated (evidence submissions)

5. **SQL Injection Prevention**:
   - Always use Django ORM (no raw SQL)
   - Use parameterized queries if raw SQL is required

6. **XSS Prevention**:
   - React escapes output by default
   - Use `dangerouslySetInnerHTML` only with sanitized content

7. **CSRF Protection**:
   - Django CSRF middleware enabled
   - CSRF token required for all POST/PUT/DELETE requests

### Common Vulnerabilities to Avoid

```python
# ❌ BAD: SQL Injection
Investigation.objects.raw(f"SELECT * FROM blockchain_investigation WHERE case_number = '{case_number}'")

# ✅ GOOD: Use ORM
Investigation.objects.filter(case_number=case_number)

# ❌ BAD: Path Traversal
file_path = f"/uploads/{request.POST['filename']}"
with open(file_path, 'rb') as f:
    # User could submit "../../../etc/passwd"

# ✅ GOOD: Validate and sanitize
import os
filename = os.path.basename(request.POST['filename'])
file_path = os.path.join(settings.UPLOAD_DIR, filename)

# ❌ BAD: Hardcoded secrets
SECRET_KEY = "django-insecure-12345"

# ✅ GOOD: Environment variables or config
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY')
```

---

## 📊 Database Schema (Key Tables)

### blockchain_investigation
```sql
CREATE TABLE blockchain_investigation (
    id SERIAL PRIMARY KEY,
    guid UUID UNIQUE NOT NULL,
    case_number VARCHAR(100) UNIQUE NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    investigator_id INTEGER REFERENCES auth_user(id),
    status VARCHAR(20) NOT NULL,  -- active, archived, closed
    chain_type VARCHAR(10) DEFAULT 'hot',  -- hot, cold
    blockchain_id VARCHAR(255),
    created_at TIMESTAMP NOT NULL,
    archived_at TIMESTAMP,
    INDEX idx_case_number (case_number),
    INDEX idx_investigator_status (investigator_id, status)
);
```

### blockchain_evidence
```sql
CREATE TABLE blockchain_evidence (
    id SERIAL PRIMARY KEY,
    investigation_id INTEGER REFERENCES blockchain_investigation(id),
    description TEXT,
    file_name VARCHAR(255) NOT NULL,
    file_hash VARCHAR(64) NOT NULL,  -- SHA-256
    ipfs_hash VARCHAR(255),
    blockchain_hash VARCHAR(255),
    submitted_by_id INTEGER REFERENCES auth_user(id),
    submitted_at TIMESTAMP NOT NULL,
    file_size BIGINT NOT NULL,
    content_type VARCHAR(100),
    INDEX idx_investigation (investigation_id),
    INDEX idx_file_hash (file_hash)
);
```

### blockchain_blockchaintransaction
```sql
CREATE TABLE blockchain_blockchaintransaction (
    id SERIAL PRIMARY KEY,
    investigation_id INTEGER REFERENCES blockchain_investigation(id),
    evidence_id INTEGER REFERENCES blockchain_evidence(id) NULL,
    transaction_type VARCHAR(50) NOT NULL,
    blockchain_tx_id VARCHAR(255) UNIQUE NOT NULL,
    transaction_data JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL,
    INDEX idx_investigation (investigation_id),
    INDEX idx_blockchain_tx_id (blockchain_tx_id)
);
```

### pki_certificate
```sql
CREATE TABLE pki_certificate (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES auth_user(id),
    ca_id INTEGER REFERENCES pki_certificateauthority(id),
    serial_number VARCHAR(40) UNIQUE NOT NULL,
    certificate TEXT NOT NULL,  -- PEM-encoded
    revoked BOOLEAN DEFAULT FALSE,
    revoked_at TIMESTAMP NULL,
    issued_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    INDEX idx_user (user_id),
    INDEX idx_serial_number (serial_number)
);
```

---

## 🎨 Frontend Architecture

### Component Hierarchy

```
App.jsx
├── AuthProvider
│   ├── ToastProvider
│   │   ├── Navbar
│   │   └── Routes
│   │       ├── /login → Login.jsx
│   │       ├── /setup-mfa → MFASetup.jsx
│   │       ├── /mfa-challenge → MFAChallenge.jsx
│   │       ├── /dashboard → <RoleBasedDashboard>
│   │       │   ├── InvestigatorDashboard.jsx
│   │       │   ├── AuditorDashboard.jsx
│   │       │   └── CourtDashboard.jsx
│   │       ├── /investigations → InvestigationList.jsx
│   │       ├── /investigations/:id → InvestigationDetailPage.jsx
│   │       └── /admin-dashboard → AdminDashboard.jsx
```

### State Management

**Global State** (via Context API):

```javascript
// AuthContext.jsx
const AuthContext = createContext({
  user: null,
  isAuthenticated: false,
  login: (credentials) => {},
  logout: () => {},
  checkAuth: () => {},
});

// ToastContext.jsx
const ToastContext = createContext({
  showToast: (message, type) => {},
  hideToast: () => {},
});
```

**Local State** (via useState/useReducer):
- Component-specific UI state (modals, forms, etc.)

**Server State** (via @tanstack/react-query):
- API data caching and synchronization

### API Client (`frontend/src/services/api.js`)

```javascript
import axios from 'axios';

const api = axios.create({
  baseURL: '/api/v1',
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor (add auth token)
api.interceptors.request.use(config => {
  const token = localStorage.getItem('authToken');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Response interceptor (handle errors)
api.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      // Redirect to login
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default api;
```

### Styling Guidelines

**Tailwind CSS Classes**:
```jsx
// Use semantic utility classes
<div className="bg-blue-600 text-white px-4 py-2 rounded-lg shadow-md hover:bg-blue-700 transition">
  Button
</div>

// Group related utilities
<div className="
  flex items-center justify-between
  px-6 py-4
  border-b border-gray-200
  hover:bg-gray-50
">
```

**Component-Specific Styles**:
- Prefer Tailwind utilities over custom CSS
- Use CSS modules only for complex animations/layouts

---

## 📚 Documentation Files (Key References)

### Getting Started
- `README.md` - Project overview
- `SETUP.md` - Installation instructions
- `FRESH_INSTALL.md` - Clean installation guide

### Architecture
- `DATABASE_ARCHITECTURE_EXPLAINED.md` - Database design
- `AUTHENTICATION_ARCHITECTURE.md` - Auth system design
- `BLOCKCHAIN_API_DOCUMENTATION.md` - API reference
- `MODIFICATIONS.md` - Changes to base JumpServer

### Development
- `DEPENDENCIES.md` - Dependency documentation
- `TESTING_GUIDE.md` - Testing procedures
- `CONTRIBUTING.md` - Contribution guidelines

### Deployment
- `DEPLOYMENT_COMPLETE.md` - Deployment summary
- `COMPLETE_DEPLOYMENT_GUIDE.md` - Production deployment
- `READY_TO_DEPLOY.md` - Pre-deployment checklist

### Troubleshooting
- `ERRORS_AND_FIXES.md` - Common errors and solutions
- `QUICK_FIX_GUIDE.md` - Quick troubleshooting
- `DATABASE_CONNECTION_FIX.md` - DB connection issues

### Feature-Specific
- `RBAC_SECURITY_IMPLEMENTATION.md` - RBAC system
- `PASSWORDLESS_AUTH_IMPLEMENTATION.md` - mTLS authentication
- `REACT_FRONTEND_IMPLEMENTATION.md` - Frontend architecture
- `MTLS_TESTING.md` - mTLS testing guide

---

## 🔄 Development Workflow Best Practices

### Branch Strategy

**Main Branches**:
- `main` - Production-ready code
- `develop` - Development integration
- `feature/*` - Feature branches (e.g., `feature/evidence-verification`)
- `bugfix/*` - Bug fix branches
- `claude/*` - AI assistant branches (auto-generated)

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code formatting (no logic changes)
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Build process, dependencies

**Examples**:
```
feat(blockchain): Add evidence verification endpoint

Implemented POST /api/v1/blockchain/evidence/{id}/verify/ endpoint
to verify evidence hash against blockchain records.

Closes #123

---

fix(pki): Fix certificate renewal task

Certificate renewal Celery task was failing due to incorrect
timezone handling. Fixed by using timezone-aware datetime objects.

Refs #456
```

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project conventions
- [ ] Self-reviewed code
- [ ] Commented complex logic
- [ ] Updated documentation
- [ ] No new warnings
- [ ] Added tests
- [ ] Tests pass locally
```

### Code Review Checklist

**Security**:
- [ ] No hardcoded secrets
- [ ] Input validation on all user inputs
- [ ] SQL injection prevention (use ORM)
- [ ] XSS prevention (escape output)
- [ ] CSRF protection enabled

**Performance**:
- [ ] Database queries optimized (no N+1)
- [ ] Appropriate use of indexes
- [ ] Large files handled asynchronously
- [ ] Caching implemented where appropriate

**Code Quality**:
- [ ] Follows PEP 8 (Python) / Airbnb style (JavaScript)
- [ ] Functions/methods have single responsibility
- [ ] Magic numbers replaced with constants
- [ ] Error handling implemented
- [ ] Logging added for important operations

**Testing**:
- [ ] Unit tests for business logic
- [ ] Integration tests for API endpoints
- [ ] Edge cases covered
- [ ] Test coverage >80%

---

## 🧪 Testing Strategy

### Test Organization

```
apps/blockchain/tests/
├── __init__.py
├── test_models.py          # Model validation tests
├── test_api.py             # API endpoint tests
├── test_serializers.py     # Serializer validation tests
├── test_services.py        # Business logic tests
└── test_clients.py         # Blockchain/IPFS client tests
```

### Example Test Cases

**Model Tests** (`test_models.py`):
```python
from django.test import TestCase
from apps.blockchain.models import Investigation

class InvestigationModelTests(TestCase):
    def test_create_investigation(self):
        inv = Investigation.objects.create(
            case_number='CASE-001',
            title='Test Investigation',
            investigator=self.user,
            status='active'
        )
        self.assertIsNotNone(inv.guid)
        self.assertEqual(inv.chain_type, 'hot')
```

**API Tests** (`test_api.py`):
```python
from rest_framework.test import APITestCase
from rest_framework import status

class InvestigationAPITests(APITestCase):
    def test_create_investigation_authenticated(self):
        self.client.force_authenticate(user=self.investigator)
        response = self.client.post('/api/v1/blockchain/investigations/', {
            'case_number': 'CASE-001',
            'title': 'Test Investigation',
            'description': 'Test'
        })
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_create_investigation_unauthenticated(self):
        response = self.client.post('/api/v1/blockchain/investigations/', {})
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
```

**Service Tests** (`test_services.py`):
```python
from django.test import TestCase
from apps.blockchain.services.archive_service import ArchiveService

class ArchiveServiceTests(TestCase):
    def test_archive_investigation(self):
        service = ArchiveService()
        result = service.archive_investigation(self.investigation.id)

        self.investigation.refresh_from_db()
        self.assertEqual(self.investigation.status, 'archived')
        self.assertEqual(self.investigation.chain_type, 'cold')
        self.assertIsNotNone(self.investigation.archived_at)
```

### Test Fixtures

**Using Django Fixtures**:
```bash
# Create fixture
python manage.py dumpdata blockchain.Investigation --indent 2 > fixtures/investigations.json

# Load fixture
python manage.py loaddata fixtures/investigations.json
```

**Using Factory Boy** (recommended):
```python
import factory
from apps.blockchain.models import Investigation

class InvestigationFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Investigation

    case_number = factory.Sequence(lambda n: f'CASE-{n:04d}')
    title = factory.Faker('sentence', nb_words=5)
    description = factory.Faker('paragraph')
    investigator = factory.SubFactory(UserFactory)
    status = 'active'
```

---

## 🔍 Key Files for AI Assistants to Reference

### Understanding the Project
1. `README.md` - Overall project description
2. `DATABASE_ARCHITECTURE_EXPLAINED.md` - Database design
3. `BLOCKCHAIN_API_DOCUMENTATION.md` - API endpoints
4. `MODIFICATIONS.md` - What was changed from base JumpServer

### Making Changes
5. `apps/blockchain/models.py` - Core blockchain models
6. `apps/blockchain/api/views.py` - API endpoint implementations
7. `apps/pki/models.py` - PKI models
8. `apps/rbac/builtin.py` - Role definitions
9. `frontend/src/App.jsx` - Frontend routing
10. `config.yml` - Main configuration

### Debugging
11. `ERRORS_AND_FIXES.md` - Common errors
12. `QUICK_FIX_GUIDE.md` - Quick fixes
13. `setup.sh` - Setup script (shows dependencies)
14. `diagnose.sh` - Diagnostic script

### Deployment
15. `DEPLOYMENT_COMPLETE.md` - Deployment process
16. `Dockerfile` - Container configuration
17. `nginx_mtls.conf` - Web server config

---

## 🎯 Common Tasks for AI Assistants

### Task: Add a New API Endpoint

**Steps**:
1. Add method to ViewSet in `apps/blockchain/api/views.py`:
   ```python
   @action(detail=True, methods=['post'])
   def custom_action(self, request, pk=None):
       obj = self.get_object()
       # Implementation
       return Response({'status': 'success'})
   ```

2. Add serializer if needed in `apps/blockchain/api/serializers.py`

3. Add permissions in `apps/blockchain/api/permissions.py`

4. Update `BLOCKCHAIN_API_DOCUMENTATION.md`

5. Write tests in `apps/blockchain/tests/test_api.py`

6. Update frontend API client if needed

### Task: Add a New Database Field

**Steps**:
1. Add field to model in `apps/blockchain/models.py`:
   ```python
   class Investigation(models.Model):
       new_field = models.CharField(max_length=100, blank=True)
   ```

2. Create migration:
   ```bash
   cd apps
   python manage.py makemigrations blockchain
   ```

3. Review migration file in `apps/blockchain/migrations/`

4. Apply migration:
   ```bash
   python manage.py migrate
   ```

5. Update serializer in `apps/blockchain/api/serializers.py`

6. Update `DATABASE_ARCHITECTURE_EXPLAINED.md`

### Task: Add a New React Component

**Steps**:
1. Create component file in `frontend/src/components/`:
   ```javascript
   // InvestigationCard.jsx
   function InvestigationCard({ investigation }) {
     return <div>{/* Component JSX */}</div>;
   }
   export default InvestigationCard;
   ```

2. Import and use in parent component

3. Add styling with Tailwind classes

4. Add to `REACT_FRONTEND_IMPLEMENTATION.md` if significant

### Task: Fix a Bug

**Steps**:
1. Check `ERRORS_AND_FIXES.md` for known issues

2. Run diagnostic script:
   ```bash
   ./diagnose.sh
   ```

3. Check logs:
   ```bash
   tail -f data/logs/jumpserver.log
   ```

4. Reproduce the issue with mock clients enabled

5. Write a failing test that reproduces the bug

6. Fix the bug

7. Verify the test now passes

8. Document the fix in `ERRORS_AND_FIXES.md`

---

## 🚀 Deployment Checklist

### Pre-Production

- [ ] Change `SECRET_KEY` to random value (>50 characters)
- [ ] Set `DEBUG: false`
- [ ] Set `ALLOWED_HOSTS` to domain list
- [ ] Configure production database credentials
- [ ] Set `BLOCKCHAIN_USE_MOCK: false`
- [ ] Set `IPFS_USE_MOCK: false`
- [ ] Deploy Hyperledger Fabric network
- [ ] Deploy IPFS nodes
- [ ] Configure `fabric-network.json` with production endpoints
- [ ] Set `MTLS_REQUIRED: true`
- [ ] Set `MFA_REQUIRED: true`
- [ ] Build frontend: `cd frontend && npm run build`
- [ ] Collect static files: `cd apps && python manage.py collectstatic`
- [ ] Run migrations: `python manage.py migrate`
- [ ] Create superuser: `python manage.py createsuperuser`
- [ ] Initialize PKI: `python manage.py init_pki`
- [ ] Configure nginx SSL/TLS (Let's Encrypt)
- [ ] Configure firewall (allow 80, 443, close 8080)
- [ ] Set up database backups
- [ ] Set up log rotation
- [ ] Configure monitoring (Prometheus/Grafana)
- [ ] Test mTLS certificate authentication
- [ ] Test MFA enrollment
- [ ] Test evidence submission end-to-end
- [ ] Perform security audit
- [ ] Load testing
- [ ] Disaster recovery plan

### Post-Deployment

- [ ] Monitor logs for errors
- [ ] Monitor Celery queue length
- [ ] Monitor database performance
- [ ] Monitor blockchain connectivity
- [ ] Monitor IPFS storage usage
- [ ] Test certificate renewal automation
- [ ] Verify backups are working
- [ ] Document production credentials (in secure vault)

---

## 🆘 Getting Help

### Documentation Priority

When troubleshooting, check in this order:
1. This file (`CLAUDE.md`)
2. `ERRORS_AND_FIXES.md`
3. `QUICK_FIX_GUIDE.md`
4. Specific feature docs (e.g., `MTLS_TESTING.md`)
5. Run `./diagnose.sh`

### Common Questions

**Q: How do I reset the admin password?**
A: Run `./reset_admin_password_simple.sh`

**Q: How do I reset MFA for a user?**
A: Run `./reset_admin_mfa.sh <username>`

**Q: Where are certificates stored?**
A: `data/certs/pki/` (user .p12 files) and `data/certs/mtls/` (CA/CRL)

**Q: How do I switch between mock and real blockchain?**
A: Edit `config.yml` and change `BLOCKCHAIN_USE_MOCK` to `true` or `false`

**Q: How do I view Celery task queue?**
A: Access Flower dashboard at `http://localhost:5555` (when running)

**Q: How do I manually trigger certificate renewal?**
A: Run `cd apps && python manage.py shell`:
```python
from apps.pki.tasks import renew_expiring_certificates
renew_expiring_certificates.delay()
```

---

## 📋 Glossary

- **CA** - Certificate Authority (Internal PKI system)
- **CoC** - Chain of Custody (evidence handling process)
- **CRL** - Certificate Revocation List
- **GUID** - Globally Unique Identifier (for anonymous evidence)
- **Hot Chain** - Active investigations with ongoing evidence collection
- **Cold Chain** - Archived investigations stored in long-term blockchain storage
- **IPFS** - InterPlanetary File System (distributed file storage)
- **mTLS** - Mutual TLS (client certificate authentication)
- **MFA** - Multi-Factor Authentication (TOTP-based)
- **PKI** - Public Key Infrastructure
- **RBAC** - Role-Based Access Control
- **TOTP** - Time-based One-Time Password (MFA method)

---

## 📝 Version History

- **2025-11-15**: Initial CLAUDE.md creation
  - Comprehensive codebase analysis
  - Architecture documentation
  - Development workflow guidelines
  - Security best practices

---

## 🤝 Contributing Guidelines for AI Assistants

When making changes to this codebase:

1. **Always read this file first** before making substantial changes
2. **Preserve existing JumpServer functionality** - this is an extension, not a replacement
3. **Follow established patterns** - look at existing code for examples
4. **Update documentation** - if you add features, update relevant `.md` files
5. **Write tests** - every new feature needs tests
6. **Security first** - validate all inputs, avoid SQL injection/XSS
7. **Use mock clients** - for development without blockchain infrastructure
8. **Check logs** - always verify your changes don't introduce errors
9. **Ask before breaking changes** - consult with users before major refactors

---

**End of CLAUDE.md**
