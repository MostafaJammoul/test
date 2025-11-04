# Complete Testing Guide - JumpServer Blockchain Chain of Custody

## 🔧 Fix Connection Issues First

### On Ubuntu VM (192.168.148.154)

Run these commands on your Ubuntu VM:

```bash
cd /opt/truefypjs

# 1. Check nginx default site is disabled
sudo rm /etc/nginx/sites-enabled/default

# 2. Verify jumpserver-mtls is enabled
sudo ln -sf /etc/nginx/sites-available/jumpserver-mtls /etc/nginx/sites-enabled/

# 3. Check nginx config
sudo nginx -t

# 4. Reload nginx
sudo systemctl reload nginx

# 5. Start Django backend
source venv/bin/activate
cd apps
python manage.py runserver 0.0.0.0:8080
```

---

## 📍 Certificate Locations

### On Ubuntu VM: `/opt/truefypjs/data/certs/`

```bash
# View certificate locations
tree /opt/truefypjs/data/certs/

# Expected structure:
/opt/truefypjs/data/certs/
├── mtls/                           # For nginx
│   ├── internal-ca.crt             # CA certificate (for nginx)
│   ├── internal-ca.crl             # Certificate Revocation List
│   ├── server.crt                  # Server SSL certificate
│   └── server.key                  # Server SSL private key
└── pki/                            # For users
    └── <username>.p12              # Your user certificate (PKCS#12 format)
```

### Download Certificate to Windows

From **Windows PowerShell** or **cmd**:

```powershell
# Using scp to download certificate from VM
scp jsroot@192.168.148.154:/opt/truefypjs/data/certs/pki/<username>.p12 C:\Users\mosta\Desktop\

# Or use WinSCP/FileZilla to download:
# Remote path: /opt/truefypjs/data/certs/pki/<username>.p12
# Local path: C:\Users\mosta\Desktop\
```

**Certificate password**: `changeme123`

---

## 🧪 Testing Checklist

### ✅ 1. Test Basic HTTP Access (No mTLS)

From **Windows** (your host):

```powershell
# Test Django backend directly (port 8080)
curl http://192.168.148.154:8080/api/health/
```

**Expected**: JSON response with `{"status": "ok"}`

---

### ✅ 2. Test HTTPS Access (No certificate - should fail)

```powershell
# This should fail with "certificate required"
curl -k https://192.168.148.154/api/health/
```

**Expected**: `400 Bad Request` or `No required SSL certificate was sent`

---

### ✅ 3. Import Certificate into Browser

#### Firefox:
1. **Settings** → **Privacy & Security** → **Certificates** → **View Certificates**
2. Click **Import**
3. Select `C:\Users\mosta\Desktop\<username>.p12`
4. Enter password: `changeme123`
5. Check "Trust this CA to identify websites"

#### Chrome:
1. **Settings** → **Privacy and security** → **Security** → **Manage certificates**
2. Click **Import** (Personal tab)
3. Select `C:\Users\mosta\Desktop\<username>.p12`
4. Enter password: `changeme123`
5. Select "Automatically select the certificate store"

---

### ✅ 4. Test mTLS HTTPS Access (With Certificate)

Open browser and navigate to:

```
https://192.168.148.154/
```

**Expected**:
1. Browser prompts for certificate selection
2. Select your certificate
3. JumpServer login page appears
4. You're automatically authenticated (no password needed!)

---

### ✅ 5. Test RBAC (Role-Based Access Control)

#### A. Check Your Current User Role

On **Ubuntu VM**:

```bash
cd /opt/truefypjs
source venv/bin/activate
cd apps

# Check superuser roles
python manage.py shell << EOF
from users.models import User
from rbac.models import Role

user = User.objects.get(username='<your_username>')
roles = user.get_roles()
print(f"User: {user.username}")
print(f"Roles: {[r.name for r in roles]}")
print(f"Is Superuser: {user.is_superuser}")
EOF
```

#### B. Create Blockchain Roles Test User

```bash
cd /opt/truefypjs/apps

# Create test user for BlockchainInvestigator role
python manage.py shell << 'EOF'
from users.models import User
from rbac.models import Role

# Create user
user = User.objects.create_user(
    username='investigator1',
    email='investigator1@test.com',
    name='Test Investigator'
)
user.set_password('testpass123')
user.save()

# Assign BlockchainInvestigator role
role = Role.objects.get(name='BlockchainInvestigator')
user.roles.add(role)

print(f"✅ Created user: {user.username}")
print(f"✅ Assigned role: {role.name}")
EOF
```

#### C. Issue Certificate for Test User

```bash
cd /opt/truefypjs/apps

python manage.py issue_user_cert \
    --username investigator1 \
    --output ../data/certs/pki/investigator1.p12 \
    --password testpass123
```

#### D. Test Role Permissions

**Log in as investigator1** (import their certificate) and test:

1. **Can create investigations**: ✅
2. **Can upload evidence**: ✅
3. **Cannot create users**: ❌ (should see "Permission denied")
4. **Cannot access admin panel**: ❌

---

### ✅ 6. Test Blockchain (Mock Mode)

#### A. Create Investigation

From **Windows** using curl:

```bash
# Get auth token first (or use mTLS)
curl -X POST http://192.168.148.154:8080/api/v1/authentication/auth/ \
  -H "Content-Type: application/json" \
  -d '{"username": "investigator1", "password": "testpass123"}'

# Save the token from response, then:
curl -X POST http://192.168.148.154:8080/api/v1/blockchain/investigations/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "title": "Test Investigation Case",
    "description": "Testing blockchain chain of custody",
    "case_number": "CASE-2025-001"
  }'
```

**Expected response**:
```json
{
  "id": "...",
  "title": "Test Investigation Case",
  "case_number": "CASE-2025-001",
  "status": "active",
  "blockchain_tx_hash": "mock_tx_abc123...",
  "created_at": "2025-01-..."
}
```

#### B. Upload Evidence

```bash
curl -X POST http://192.168.148.154:8080/api/v1/blockchain/evidence/ \
  -H "Authorization: Bearer <token>" \
  -F "investigation=<investigation_id>" \
  -F "file=@C:\Users\mosta\Desktop\test_evidence.txt" \
  -F "description=Test evidence file"
```

**Expected response**:
```json
{
  "id": "...",
  "file_hash": "sha256:...",
  "ipfs_cid": "QmMock...",
  "blockchain_tx_hash": "mock_tx_def456...",
  "uploaded_by": "investigator1"
}
```

#### C. Verify Blockchain Transaction

On **Ubuntu VM**:

```bash
cd /opt/truefypjs/apps

python manage.py shell << 'EOF'
from blockchain.models import Investigation, Evidence, BlockchainTransaction

# Check investigation was recorded
inv = Investigation.objects.first()
print(f"Investigation: {inv.title}")
print(f"Blockchain TX: {inv.blockchain_tx_hash}")
print(f"Status: {inv.status}")

# Check evidence was recorded
evidence = Evidence.objects.first()
print(f"\nEvidence: {evidence.description}")
print(f"IPFS CID: {evidence.ipfs_cid}")
print(f"Blockchain TX: {evidence.blockchain_tx_hash}")

# Check blockchain transactions
txs = BlockchainTransaction.objects.all()
print(f"\nTotal blockchain transactions: {txs.count()}")
for tx in txs:
    print(f"  - TX: {tx.transaction_hash} | Chain: {tx.chain_type}")
EOF
```

---

### ✅ 7. Test Mock IPFS Storage

#### A. Check IPFS Storage Location

On **Ubuntu VM**:

```bash
cd /opt/truefypjs

# List uploaded files (mock IPFS)
ls -lh data/uploads/

# View file metadata
python apps/manage.py shell << 'EOF'
from blockchain.models import Evidence

for e in Evidence.objects.all():
    print(f"File: {e.file_name}")
    print(f"  IPFS CID: {e.ipfs_cid}")
    print(f"  File Hash: {e.file_hash}")
    print(f"  Size: {e.file_size} bytes")
    print(f"  Location: data/uploads/{e.ipfs_cid}")
    print()
EOF
```

#### B. Verify File Integrity

```bash
cd /opt/truefypjs/apps

python manage.py shell << 'EOF'
import hashlib
from blockchain.models import Evidence

evidence = Evidence.objects.first()
if evidence:
    # Read file from mock IPFS storage
    with open(f'../data/uploads/{evidence.ipfs_cid}', 'rb') as f:
        file_data = f.read()

    # Calculate hash
    calculated_hash = hashlib.sha256(file_data).hexdigest()

    print(f"Stored hash: {evidence.file_hash}")
    print(f"Calculated hash: sha256:{calculated_hash}")
    print(f"Match: {evidence.file_hash == f'sha256:{calculated_hash}'}")
else:
    print("No evidence uploaded yet")
EOF
```

---

### ✅ 8. Test Hot/Cold Chain Architecture

#### A. Archive Investigation (Move to Cold Chain)

```bash
cd /opt/truefypjs/apps

python manage.py shell << 'EOF'
from blockchain.models import Investigation
from blockchain.services.archive_service import ArchiveService

inv = Investigation.objects.first()
if inv:
    # Archive to cold chain
    archive_service = ArchiveService()
    result = archive_service.archive_investigation(inv.id)

    print(f"Investigation: {inv.title}")
    print(f"Status: {inv.status}")
    print(f"Cold chain TX: {result['cold_chain_tx_hash']}")

    # Verify it's on cold chain
    inv.refresh_from_db()
    print(f"New status: {inv.status}")
else:
    print("No investigation found")
EOF
```

#### B. Verify Cold Chain Transaction

```bash
cd /opt/truefypjs/apps

python manage.py shell << 'EOF'
from blockchain.models import BlockchainTransaction

# Check cold chain transactions
cold_txs = BlockchainTransaction.objects.filter(chain_type='cold')
print(f"Cold chain transactions: {cold_txs.count()}")

for tx in cold_txs:
    print(f"  TX: {tx.transaction_hash}")
    print(f"  Investigation: {tx.investigation.title if tx.investigation else 'N/A'}")
EOF
```

---

### ✅ 9. Test Certificate Revocation

#### A. Revoke Certificate

On **Ubuntu VM**:

```bash
cd /opt/truefypjs/apps

# Revoke investigator1's certificate
python manage.py shell << 'EOF'
from pki.models import Certificate

cert = Certificate.objects.get(user__username='investigator1')
cert.revoked = True
cert.save()

print(f"✅ Revoked certificate for: {cert.user.username}")
print(f"Serial: {cert.serial_number}")
EOF
```

#### B. Update CRL

```bash
cd /opt/truefypjs/apps

# Export updated CRL
python manage.py export_crl --output ../data/certs/mtls/internal-ca.crl --force

# Reload nginx to use updated CRL
sudo systemctl reload nginx
```

#### C. Test Revoked Certificate

From **Windows**:
- Try accessing `https://192.168.148.154/` with investigator1's certificate
- **Expected**: `403 Forbidden` or certificate error

---

### ✅ 10. Test Database Storage

#### A. Check PostgreSQL Tables

On **Ubuntu VM**:

```bash
# Connect to PostgreSQL
PGPASSWORD=jsroot psql -h 127.0.0.1 -U jumpserver -d jumpserver

-- Check PKI tables
\dt pki_*

-- Check blockchain tables
\dt blockchain_*

-- View CA certificate
SELECT id, name, valid_from, valid_until, is_active
FROM pki_certificateauthority;

-- View user certificates
SELECT id, user_id, serial_number, issued_at, expires_at, revoked
FROM pki_certificate;

-- View investigations
SELECT id, title, case_number, status, blockchain_tx_hash
FROM blockchain_investigation;

-- View evidence
SELECT id, file_name, ipfs_cid, blockchain_tx_hash
FROM blockchain_evidence;

-- Exit
\q
```

---

## 🎯 Quick Test Script

Save this on **Ubuntu VM** as `/opt/truefypjs/run_tests.sh`:

```bash
#!/bin/bash
cd /opt/truefypjs
source venv/bin/activate
cd apps

echo "=== Testing JumpServer Blockchain ==="
echo

echo "1. Checking database connection..."
python manage.py check --database default
echo

echo "2. Checking PKI setup..."
python manage.py shell -c "from pki.models import CertificateAuthority; print(f'✅ CA: {CertificateAuthority.objects.first().name}')"
echo

echo "3. Checking user certificates..."
python manage.py shell -c "from pki.models import Certificate; print(f'✅ Certificates issued: {Certificate.objects.count()}')"
echo

echo "4. Checking blockchain roles..."
python manage.py shell -c "from rbac.models import Role; roles = Role.objects.filter(name__startswith='Blockchain'); print(f'✅ Blockchain roles: {[r.name for r in roles]}')"
echo

echo "5. Checking investigations..."
python manage.py shell -c "from blockchain.models import Investigation; print(f'✅ Investigations: {Investigation.objects.count()}')"
echo

echo "6. Checking evidence..."
python manage.py shell -c "from blockchain.models import Evidence; print(f'✅ Evidence items: {Evidence.objects.count()}')"
echo

echo "7. Checking blockchain transactions..."
python manage.py shell -c "from blockchain.models import BlockchainTransaction; hot = BlockchainTransaction.objects.filter(chain_type='hot').count(); cold = BlockchainTransaction.objects.filter(chain_type='cold').count(); print(f'✅ Hot chain: {hot} | Cold chain: {cold}')"
echo

echo "=== All tests complete! ==="
```

Run it:

```bash
chmod +x /opt/truefypjs/run_tests.sh
/opt/truefypjs/run_tests.sh
```

---

## 📊 Access URLs Summary

| Service | URL | Requires mTLS |
|---------|-----|---------------|
| **Django Backend (Direct)** | http://192.168.148.154:8080 | No |
| **nginx + mTLS** | https://192.168.148.154 | Yes |
| **Admin Panel** | https://192.168.148.154/admin/ | Yes |
| **API Root** | https://192.168.148.154/api/v1/ | Yes (or token) |
| **Blockchain API** | https://192.168.148.154/api/v1/blockchain/ | Yes (or token) |

---

## 🔍 Troubleshooting

### Problem: "Welcome to nginx" page

**Solution**:
```bash
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl reload nginx
```

### Problem: Connection refused on port 8080

**Solution**:
```bash
cd /opt/truefypjs
source venv/bin/activate
cd apps
python manage.py runserver 0.0.0.0:8080
```

### Problem: Can't import certificate in browser

**Solution**:
- Make sure file is `.p12` format
- Password is `changeme123`
- Try Firefox if Chrome doesn't work

### Problem: Certificate not trusted

**Solution**:
```bash
# Export CA certificate
cd /opt/truefypjs/apps
python manage.py export_ca_cert --output ../ca.crt --force

# Download ca.crt to Windows and install it as Trusted Root CA
```

---

## ✅ Success Indicators

You'll know everything is working when:

1. ✅ nginx shows JumpServer, not "Welcome to nginx"
2. ✅ Port 8080 shows Django API response
3. ✅ HTTPS requires certificate
4. ✅ Browser certificate prompt appears
5. ✅ Automatic login after selecting certificate
6. ✅ Can create investigations via API
7. ✅ Evidence uploads store in `data/uploads/`
8. ✅ Blockchain transactions appear in database
9. ✅ RBAC roles restrict access correctly
10. ✅ Revoked certificates are rejected

---

**Done!** You now have a fully functional blockchain chain-of-custody system with mTLS authentication.
