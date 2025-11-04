# Fixed Testing Guide - JumpServer Blockchain

**Use this guide instead of the original TESTING_GUIDE.md**

This guide contains all the fixes for the issues you encountered.

---

## 🔧 Step 0: Fix Your Setup Issues

### **Run the diagnostic first:**

```bash
cd /opt/truefypjs
chmod +x diagnose.sh
./diagnose.sh
```

### **If you see failures, run the fix script:**

```bash
chmod +x fix_setup.sh
./fix_setup.sh
```

This will:
- ✅ Create missing certificate directories
- ✅ Export CA certificates for nginx
- ✅ Generate server SSL certificates
- ✅ Configure nginx properly
- ✅ Remove default nginx site
- ✅ Issue certificates for existing superusers

---

## 📍 Certificate Locations (Fixed)

### **Your Certificates:**

```
/opt/truefypjs/data/certs/
├── mtls/                           # For nginx
│   ├── internal-ca.crt             # CA certificate (exported from DB)
│   ├── internal-ca.crl             # Certificate Revocation List
│   ├── server.crt                  # Server SSL certificate
│   └── server.key                  # Server SSL private key
└── pki/                            # For users
    └── <username>.p12              # Your user certificate
```

**Certificate password**: `changeme123`

### **Download to Windows:**

```powershell
# From Windows PowerShell/cmd
scp jsroot@192.168.148.154:/opt/truefypjs/data/certs/pki/<username>.p12 C:\Users\mosta\Desktop\
```

---

## ✅ Test 1: Start Django Backend (MUST DO FIRST!)

On **Ubuntu VM**:

```bash
cd /opt/truefypjs
source venv/bin/activate
cd apps
python manage.py runserver 0.0.0.0:8080
```

**Keep this terminal running!**

### **Test from Windows:**

```powershell
# Test Django backend directly
curl http://192.168.148.154:8080/api/health/
```

**Expected**: `{"status":"ok"}` or similar

---

## ✅ Test 2: Test nginx (After fixing)

### **Check nginx is running:**

On **Ubuntu VM**:
```bash
sudo systemctl status nginx
sudo systemctl reload nginx
```

### **Test from Windows:**

```powershell
# Test HTTPS without certificate (should fail)
curl -k https://192.168.148.154/api/health/
```

**Expected**: `400 Bad Request` or `No required SSL certificate was sent`

If you get **connection refused**, nginx is not listening on port 443. Check:

```bash
# On Ubuntu VM
sudo netstat -tlnp | grep nginx
# You should see lines with :80 and :443
```

If not listening on 443, check nginx error log:

```bash
sudo tail -50 /var/log/nginx/error.log
```

---

## ✅ Test 3: RBAC (FIXED - No More GUID Error!)

### **Run the fixed RBAC test:**

On **Ubuntu VM**:

```bash
cd /opt/truefypjs
chmod +x test_rbac.sh
./test_rbac.sh
```

This script will:
1. ✅ List all users and their roles (no GUID error!)
2. ✅ Show available blockchain roles
3. ✅ Create `investigator1` user with BlockchainInvestigator role
4. ✅ Issue certificate for investigator1
5. ✅ List all issued certificates

### **Manual RBAC check (if you want to check a specific user):**

```bash
cd /opt/truefypjs
source venv/bin/activate
cd apps

# Replace <your_username> with actual username
python manage.py shell << 'EOF'
from users.models import User
from rbac.models import SystemRoleBinding

# Get user
username = 'admin'  # Change this to your username
user = User.objects.get(username=username)

print(f"User: {user.username}")
print(f"Email: {user.email}")
print(f"Is superuser: {user.is_superuser}")

# Get roles
bindings = SystemRoleBinding.objects.filter(user=user)
print(f"\nSystem Roles:")
for binding in bindings:
    print(f"  - {binding.role.name} (ID: {binding.role.id})")
EOF
```

---

## ✅ Test 4: Import Certificate into Browser

### **Firefox** (Recommended):

1. **Settings** → **Privacy & Security** → **Certificates** → **View Certificates**
2. Click **Import** under **Your Certificates** tab
3. Select `C:\Users\mosta\Desktop\<username>.p12`
4. Enter password: `changeme123`
5. Click OK

Also import the CA certificate:
1. Download CA cert: `scp jsroot@192.168.148.154:/opt/truefypjs/data/certs/mtls/internal-ca.crt C:\Users\mosta\Desktop\`
2. **Authorities** tab → **Import**
3. Select `internal-ca.crt`
4. Check **"Trust this CA to identify websites"**
5. Click OK

### **Chrome**:

1. **Settings** → **Privacy and security** → **Security** → **Manage certificates**
2. **Personal** tab → **Import**
3. Select the `.p12` file
4. Enter password: `changeme123`
5. Next → Place certificate in automatic store

Also import CA:
1. **Trusted Root Certification Authorities** tab → **Import**
2. Select `internal-ca.crt`

---

## ✅ Test 5: Test mTLS Authentication

### **In Browser:**

```
https://192.168.148.154/
```

**Expected**:
1. Browser prompts you to select a certificate
2. Select your certificate
3. JumpServer page loads
4. You are automatically authenticated

**If browser doesn't prompt for certificate:**
- Make sure certificate is imported correctly
- Check browser supports client certificates
- Try Firefox instead of Chrome
- Check nginx logs: `sudo tail -f /var/log/nginx/jumpserver-mtls-error.log`

---

## ✅ Test 6: Blockchain Operations (Mock Mode)

### **A. Get Authentication Token:**

From **Windows** or **Ubuntu**:

```bash
# Using investigator1 credentials
curl -X POST http://192.168.148.154:8080/api/v1/authentication/auth/ \
  -H "Content-Type: application/json" \
  -d '{"username": "investigator1", "password": "testpass123"}'
```

Save the token from the response.

### **B. Create Investigation:**

```bash
TOKEN="<token_from_previous_command>"

curl -X POST http://192.168.148.154:8080/api/v1/blockchain/investigations/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "title": "Test Investigation Case",
    "description": "Testing blockchain chain of custody",
    "case_number": "CASE-2025-001"
  }'
```

**Expected Response:**

```json
{
  "id": "uuid",
  "title": "Test Investigation Case",
  "case_number": "CASE-2025-001",
  "status": "active",
  "created_at": "2025-11-04T...",
  "created_by": "investigator1"
}
```

Save the `id` value.

### **C. Upload Evidence:**

Create a test file first:

```bash
echo "This is test evidence" > /tmp/test_evidence.txt
```

Then upload:

```bash
INVESTIGATION_ID="<id_from_previous_command>"
TOKEN="<your_token>"

curl -X POST http://192.168.148.154:8080/api/v1/blockchain/evidence/ \
  -H "Authorization: Bearer $TOKEN" \
  -F "investigation=$INVESTIGATION_ID" \
  -F "file=@/tmp/test_evidence.txt" \
  -F "title=Test Evidence" \
  -F "description=Test evidence file"
```

**Expected Response:**

```json
{
  "id": "uuid",
  "file_name": "test_evidence.txt",
  "file_hash_sha256": "abc123...",
  "ipfs_cid": "QmMock...",
  "uploaded_by": "investigator1"
}
```

### **D. Verify Files Were Created:**

On **Ubuntu VM**:

```bash
cd /opt/truefypjs

# Check mock IPFS storage
ls -lh data/mock_ipfs/

# Check mock blockchain storage
ls -lh data/mock_blockchain/hot/
```

You should see files!

---

## ✅ Test 7: Verify in Database

On **Ubuntu VM**:

```bash
cd /opt/truefypjs
source venv/bin/activate
cd apps

python manage.py shell << 'EOF'
from blockchain.models import Investigation, Evidence, BlockchainTransaction

# Check investigations
inv = Investigation.objects.first()
if inv:
    print(f"Investigation: {inv.title}")
    print(f"  Case Number: {inv.case_number}")
    print(f"  Status: {inv.status}")
    print(f"  Created by: {inv.created_by.username if inv.created_by else 'N/A'}")
else:
    print("No investigations found")

print()

# Check evidence
evidence = Evidence.objects.first()
if evidence:
    print(f"Evidence: {evidence.title}")
    print(f"  File: {evidence.file_name}")
    print(f"  IPFS CID: {evidence.ipfs_cid}")
    print(f"  SHA-256: {evidence.file_hash_sha256}")
    print(f"  Uploaded by: {evidence.uploaded_by.username if evidence.uploaded_by else 'N/A'}")
else:
    print("No evidence found")

print()

# Check blockchain transactions
txs = BlockchainTransaction.objects.all()
print(f"Total blockchain transactions: {txs.count()}")
for tx in txs:
    print(f"  - {tx.chain_type} chain: {tx.transaction_hash[:16]}...")
    print(f"    Block: {tx.block_number}")
    print(f"    Investigation: {tx.investigation.case_number if tx.investigation else 'N/A'}")
EOF
```

---

## 🔍 Troubleshooting

### **Problem: Port 8080 connection refused**

**Solution**: Django backend is not running. Start it:

```bash
cd /opt/truefypjs
source venv/bin/activate
cd apps
python manage.py runserver 0.0.0.0:8080
```

### **Problem: Port 443 connection refused**

**Solution**: nginx not listening on HTTPS. Check:

```bash
# Check nginx is running
sudo systemctl status nginx

# Check if listening on 443
sudo netstat -tlnp | grep :443

# If not, check error log
sudo tail -50 /var/log/nginx/error.log

# Common issue: certificate paths wrong in nginx config
sudo nano /etc/nginx/sites-available/jumpserver-mtls
# Verify all paths start with /opt/truefypjs/ (absolute paths!)
```

### **Problem: "Welcome to nginx" page**

**Solution**: Default site still enabled:

```bash
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl reload nginx
```

### **Problem: No certificates in /data/certs/mtls/**

**Solution**: Run the fix script:

```bash
cd /opt/truefypjs
./fix_setup.sh
```

### **Problem: GUID error when checking roles**

**Solution**: Use the fixed test_rbac.sh script:

```bash
cd /opt/truefypjs
./test_rbac.sh
```

The original command had an error. The fixed version uses `SystemRoleBinding` instead of `user.system_roles`.

---

## 📊 Summary of What Was Fixed

### **1. Missing Certificates** ❌ → ✅
- **Problem**: `data/certs/mtls/` directory didn't exist
- **Fix**: `fix_setup.sh` creates directories and exports certificates

### **2. nginx Not Working** ❌ → ✅
- **Problem**: nginx config had wrong paths or default site interfering
- **Fix**: `fix_setup.sh` creates proper config with absolute paths and removes default site

### **3. RBAC GUID Error** ❌ → ✅
- **Problem**: Original test used `user.system_roles.all()` which doesn't exist
- **Fix**: `test_rbac.sh` uses `SystemRoleBinding.objects.filter(user=user)` instead

### **4. Port 8080 Refused** ❌ → ✅
- **Problem**: Django backend not running
- **Fix**: Explicitly start Django with `python manage.py runserver 0.0.0.0:8080`

---

## 🎯 Quick Start (After Fixes)

```bash
# On Ubuntu VM

# 1. Run diagnostic
cd /opt/truefypjs
./diagnose.sh

# 2. Fix any issues
./fix_setup.sh

# 3. Start Django backend
source venv/bin/activate
cd apps
python manage.py runserver 0.0.0.0:8080
# Keep this running!

# 4. In another terminal, test RBAC
cd /opt/truefypjs
./test_rbac.sh

# 5. Download certificate to Windows
# From Windows:
scp jsroot@192.168.148.154:/opt/truefypjs/data/certs/pki/admin.p12 C:\Users\mosta\Desktop\
# Password: changeme123

# 6. Import certificate into Firefox/Chrome

# 7. Access https://192.168.148.154/ in browser
```

---

**All issues fixed! 🎉**
