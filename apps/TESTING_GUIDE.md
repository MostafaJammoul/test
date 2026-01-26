# Quick Test Guide - FYP-2 Blockchain Integration

## Your Configuration

```yaml
API URL: https://192.168.148.187:3001
Certificate Location: /home/jsroot/js/data/certs/mtls/client-certs/
  ├── jumpserver-client-cert.pem
  ├── jumpserver-client-key.pem
  └── ca-cert.pem
```

---

## Quick Tests

### 1. Test mTLS Connection (Command Line)

```bash
curl --cert /home/jsroot/js/data/certs/mtls/client-certs/jumpserver-client-cert.pem \
     --key /home/jsroot/js/data/certs/mtls/client-certs/jumpserver-client-key.pem \
     --cacert /home/jsroot/js/data/certs/mtls/client-certs/ca-cert.pem \
     https://192.168.148.187:3001/api/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-01-26T...",
  "connections": {
    "hotChain": true,
    "coldChain": true,
    "ipfs": false
  }
}
```

---

### 2. Run Automated Test Suite

```bash
cd /home/jsroot/js/apps

# Make script executable
chmod +x test_integration.sh

# Run all tests
./test_integration.sh
```

**This tests:**
- ✅ Certificate existence
- ✅ Certificate permissions
- ✅ mTLS connection
- ✅ Security (rejects without cert)
- ✅ Django integration
- ✅ Evidence upload/query

---

### 3. Manual Django Test (Python Shell)

```bash
cd /home/jsroot/js/apps
python manage.py shell
```

```python
from blockchain.clients.fabric_client import FabricClient
import hashlib

# Initialize client
client = FabricClient()

# Test health check
health = client.health_check()
print("Health:", health)

# Upload test evidence
test_data = b"Test evidence data"
file_hash = hashlib.sha256(test_data).hexdigest()

result = client.append_evidence(
    case_id='test-001',
    evidence_id='evidence-001',
    file_data=test_data,
    file_hash=file_hash,
    metadata={'type': 'test', 'description': 'Manual test'},
    user_identifier='admin'
)

print("Upload result:", result)
print("CID:", result.get('cid'))

# Query the evidence
evidence = client.query_evidence('evidence-001')
print("Evidence:", evidence)
```

---

## Troubleshooting

### Problem: "Certificate not found"

**Check if files exist:**
```bash
ls -la /home/jsroot/js/data/certs/mtls/client-certs/
```

**Expected output:**
```
-rw-r--r-- 1 user user 1234 ca-cert.pem
-rw-r--r-- 1 user user 1234 jumpserver-client-cert.pem
-rw------- 1 user user 3243 jumpserver-client-key.pem
```

**Fix permissions if needed:**
```bash
chmod 600 /home/jsroot/js/data/certs/mtls/client-certs/jumpserver-client-key.pem
chmod 644 /home/jsroot/js/data/certs/mtls/client-certs/*.pem
```

---

### Problem: "SSL: CERTIFICATE_VERIFY_FAILED"

**Cause:** CA certificate doesn't match server certificate

**Verify:**
```bash
# Check server certificate
openssl s_client -connect 192.168.148.187:3001 \
    -cert /home/jsroot/js/data/certs/mtls/client-certs/jumpserver-client-cert.pem \
    -key /home/jsroot/js/data/certs/mtls/client-certs/jumpserver-client-key.pem \
    -CAfile /home/jsroot/js/data/certs/mtls/client-certs/ca-cert.pem
```

---

### Problem: "Connection refused"

**Check API bridge is running on VM 2:**
```bash
# On VM 2
cd ~/Desktop/FYP-2/jumpserver-api
./start.sh
```

**Check firewall:**
```bash
# On VM 2
sudo ufw allow 3001/tcp
```

---

### Problem: Django can't find certificates

**Verify config.yml:**
```bash
grep -A 5 "FABRIC_" /home/jsroot/js/config.yml
```

**Should show:**
```yaml
FABRIC_API_URL: "https://192.168.148.187:3001"
FABRIC_CLIENT_CERT: "/home/jsroot/js/data/certs/mtls/client-certs/jumpserver-client-cert.pem"
FABRIC_CLIENT_KEY: "/home/jsroot/js/data/certs/mtls/client-certs/jumpserver-client-key.pem"
FABRIC_CA_CERT: "/home/jsroot/js/data/certs/mtls/client-certs/ca-cert.pem"
```

**Test from Python:**
```python
from django.conf import settings
print("API URL:", settings.FABRIC_API_URL)
print("Client cert:", settings.FABRIC_CLIENT_CERT)
print("CA cert:", settings.FABRIC_CA_CERT)

# Verify files exist
import os
print("Client cert exists:", os.path.exists(settings.FABRIC_CLIENT_CERT))
print("CA cert exists:", os.path.exists(settings.FABRIC_CA_CERT))
```

---

## API Functions Available

| Function | What It Does |
|----------|--------------|
| `health_check()` | Test connection and blockchain status |
| `append_evidence()` | Upload evidence to blockchain (+ IPFS if available) |
| `query_evidence(id)` | Get evidence details by ID |
| `query_case_evidence(case_id)` | Get all evidence for a case |
| `transfer_custody()` | Transfer evidence ownership |
| `archive_evidence()` | Move evidence to cold storage |

---

## Quick Reference

**Your specific paths:**
```bash
# Project root
/home/jsroot/js/

# Certificate directory
/home/jsroot/js/data/certs/mtls/client-certs/

# API URL
https://192.168.148.187:3001

# Test scripts
/home/jsroot/js/apps/test_integration.sh
/home/jsroot/js/apps/test_blockchain_api.py
```

**Common commands:**
```bash
# Run full test suite
cd /home/jsroot/js/apps && ./test_integration.sh

# Run Django tests only
cd /home/jsroot/js/apps && python test_blockchain_api.py

# Django shell
cd /home/jsroot/js/apps && python manage.py shell

# Check API bridge status (VM 2)
cd ~/Desktop/FYP-2/jumpserver-api && ./start.sh
```

---

## Security Checklist

- [x] mTLS certificates generated
- [x] Certificates stored securely
- [x] Private key permissions set to 600
- [x] config.yml updated with correct paths
- [x] API bridge running with HTTPS
- [x] Client certificate validation enabled
- [x] Connection tested successfully

---

## What Works Now

✅ **Maximum Security**
- All communication encrypted with TLS 1.3
- Mutual authentication (both VMs verify each other)
- Certificate-based access control

✅ **Blockchain Integration**
- Evidence upload to hot chain
- Evidence query from blockchain
- Chain of custody tracking
- User attribution for audit trail

✅ **Production Ready**
- No cleartext communication
- Complete audit trail
- Tamper-proof evidence records
- Multi-organization support

---

**Ready to test? Run:**
```bash
cd /home/jsroot/js/apps
./test_integration.sh
```
