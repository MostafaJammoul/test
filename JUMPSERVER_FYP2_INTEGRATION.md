# JumpServer ↔ FYP-2 Blockchain Integration Guide

This guide walks you through integrating your JumpServer (VM 1) with the FYP-2 blockchain backend (VM 2).

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    VM 1: JumpServer                         │
│                                                             │
│  Django Backend (port 8080)                                 │
│  ├── blockchain/clients/fabric_client_rest.py              │
│  │   └── Makes REST API calls to VM 2                      │
│  └── React Frontend (port 3000)                            │
│      └── Evidence upload, investigations dashboard          │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │ HTTPS + mTLS (optional)
                   │ http://vm2-ip:3001/api/*
                   │
┌──────────────────▼──────────────────────────────────────────┐
│                    VM 2: FYP-2 Blockchain                   │
│                                                             │
│  Node.js REST API Bridge (port 3001)                       │
│  ├── /api/evidence (POST) - Create evidence                │
│  ├── /api/evidence/:id (GET) - Query evidence              │
│  ├── /api/evidence/case/:id (GET) - Query by case         │
│  └── /api/health (GET) - Health check                      │
│      │                                                       │
│      ├──►Hyperledger Fabric Hot Chain (port 7051)          │
│      │   └── 3 Orderers + 2 Peers + CouchDB                │
│      │                                                       │
│      ├──►Hyperledger Fabric Cold Chain (port 9051)         │
│      │   └── 3 Orderers + 2 Peers + CouchDB                │
│      │                                                       │
│      └──►IPFS Cluster (port 5001)                          │
│          └── 4 Nodes (Lab, Court, Redundant, Replica)      │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### VM 1 (JumpServer)
- ✅ JumpServer already running
- ✅ Django + React frontend
- ✅ Python 3.11+
- Network access to VM 2

### VM 2 (Blockchain)
- ✅ FYP-2 blockchain already running (you confirmed this)
- Node.js 18+ (for REST API bridge)
- Docker containers running:
  - Fabric peers (hot + cold chains)
  - IPFS nodes
  - CouchDB

---

## Step 1: Verify Blockchain VM is Running

**On VM 2**, run the status check script:

```bash
cd /path/to/FYP-2
bash check-blockchain-status.sh
```

**Expected output:**
```
================================
FYP-2 Blockchain Status Check
================================

1. Docker Containers:
--------------------
peer0.forensiclab.hot.coc.com   Up      7051/tcp
peer0.forensiclab.cold.coc.com  Up      9051/tcp
orderer.hot.coc.com             Up      7050/tcp
ipfs-lab                        Up      5001/tcp
couchdb0                        Up      5984/tcp

2. Hyperledger Fabric Peers:
---------------------------
✓ Hot peer running
✓ Cold peer running

3. IPFS Cluster:
---------------
✓ IPFS node running (ID: Qm...)

4. Open Ports:
-------------
✓ 5001 (IPFS API)
✓ 7051 (Hot peer)
✓ 9051 (Cold peer)
✓ 9094 (IPFS Cluster)

================================
Status check complete!
================================
```

⚠️ **If anything is not running**, start the services:
```bash
cd FYP-2/blockchain
./start-all.sh

cd ../ipfs/scripts
./start-ipfs-cluster.sh
```

---

## Step 2: Install REST API Bridge on VM 2

**On VM 2**, install the Node.js REST API bridge:

```bash
cd FYP-2/jumpserver-api

# Make start script executable
chmod +x start.sh

# Install dependencies and start
./start.sh
```

**Expected output:**
```
================================
JumpServer-Fabric API Bridge
================================

Installing dependencies...
✓ Dependencies installed

Starting API bridge...
Initializing JumpServer-Fabric API Bridge...
✓ Connected to hot chain
✓ Connected to cold chain
✓ Connected to IPFS at http://localhost:5001
✓ All connections established
✓ HTTP server listening on port 3001
  Endpoint: http://0.0.0.0:3001
```

⚠️ **If you get errors:**
- **"Cannot find module"**: Run `npm install` in the `jumpserver-api/` directory
- **"ECONNREFUSED"**: Check that Fabric peers are running (port 7051, 9051)
- **"IPFS connection failed"**: Check IPFS is running (port 5001)

### Test the API Bridge

```bash
# Health check
curl http://localhost:3001/api/health

# Expected response:
{
  "status": "healthy",
  "timestamp": "2026-01-25T...",
  "connections": {
    "hotChain": true,
    "coldChain": true,
    "ipfs": true
  }
}
```

---

## Step 3: Configure JumpServer to Use FYP-2

**On VM 1 (JumpServer)**, update the configuration:

### 3.1 Update `config.yml`

```bash
cd /home/user/test
nano config.yml
```

Add these settings at the end:

```yaml
# FYP-2 Blockchain Integration
FABRIC_API_URL: "http://VM2_IP_ADDRESS:3001"  # Replace with actual IP
FABRIC_USE_REST: true

# Optional: mTLS configuration (for production)
# FABRIC_CLIENT_CERT: "/path/to/jumpserver-client.crt"
# FABRIC_CLIENT_KEY: "/path/to/jumpserver-client.key"
# FABRIC_CA_CERT: "/path/to/ca.crt"
```

**Replace `VM2_IP_ADDRESS`** with your blockchain VM's IP address.

### 3.2 Update Django Settings

```bash
nano apps/jumpserver/settings/base.py
```

Add at the end (around line 250):

```python
# FYP-2 Blockchain Configuration
FABRIC_API_URL = CONFIG.FABRIC_API_URL
FABRIC_USE_REST = CONFIG.get('FABRIC_USE_REST', True)

# Optional mTLS
FABRIC_CLIENT_CERT = CONFIG.get('FABRIC_CLIENT_CERT')
FABRIC_CLIENT_KEY = CONFIG.get('FABRIC_CLIENT_KEY')
FABRIC_CA_CERT = CONFIG.get('FABRIC_CA_CERT', True)
```

### 3.3 Replace Fabric Client

Backup the old client and use the REST client:

```bash
cd /home/user/test/apps/blockchain/clients

# Backup old client
mv fabric_client.py fabric_client_old.py

# Use REST client
cp fabric_client_rest.py fabric_client.py
```

---

## Step 4: Update Evidence Upload View

The existing evidence upload view needs to pass the file data to the new client:

```bash
cd /home/user/test/apps/blockchain/api
nano views.py
```

Find the `EvidenceViewSet.create()` method and ensure it calls:

```python
# Around line 150-200 in views.py
def create(self, request, *args, **kwargs):
    # ... existing validation code ...

    # Upload to blockchain + IPFS
    from blockchain.clients.fabric_client import FabricClient

    fabric_client = FabricClient(chain_type='hot')

    result = fabric_client.append_evidence(
        case_id=investigation.id,
        evidence_id=evidence.id,
        file_data=uploaded_file.read(),  # File bytes
        file_hash=evidence.file_hash,
        metadata={
            'filename': evidence.original_filename,
            'file_size': evidence.file_size,
            'case_id': str(investigation.id),
            'investigator': request.user.username
        },
        user_identifier=request.user.username
    )

    if result['success']:
        evidence.ipfs_cid = result['cid']
        evidence.blockchain_tx_id = result.get('tx_id')
        evidence.save()

        return Response(serializer.data, status=status.HTTP_201_CREATED)
    else:
        return Response({'error': result['error']}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
```

---

## Step 5: Test the Integration

### 5.1 Restart JumpServer

```bash
# On VM 1
cd /home/user/test/apps
python manage.py runserver 0.0.0.0:8080
```

### 5.2 Test Evidence Upload

1. **Login to JumpServer**: http://VM1_IP:3000/admin
2. **Create a new investigation** (if none exists)
3. **Upload evidence**:
   - Go to investigation detail page
   - Click "Upload Evidence"
   - Select a file (image, document, etc.)
   - Submit

4. **Verify in logs**:

**VM 1 (JumpServer) logs:**
```
[INFO] Uploading evidence abc-123 to blockchain...
[INFO] Evidence abc-123 uploaded successfully. CID: QmX5yZ...
```

**VM 2 (API Bridge) logs:**
```
POST /api/evidence
Creating evidence abc-123 for case inv-456...
✓ Uploaded to IPFS: QmX5yZ...
✓ Evidence abc-123 created on blockchain
```

### 5.3 Test Evidence Query

**From Django shell:**

```bash
cd /home/user/test/apps
python manage.py shell
```

```python
from blockchain.clients.fabric_client import FabricClient

client = FabricClient()

# Health check
health = client.health_check()
print(health)
# Should show: {'status': 'healthy', ...}

# Query evidence (replace with actual evidence ID)
evidence = client.query_evidence('abc-123')
print(evidence)
# Should show evidence data from blockchain

# Query case evidence
case_evidence = client.query_case_evidence('inv-456')
print(f"Found {len(case_evidence)} evidence records")
```

---

## Step 6: Verify on Blockchain Explorer (Optional)

FYP-2 includes a blockchain explorer. **On VM 2**:

```bash
cd FYP-2/blockchain/explorer
python api-server.py &
```

Then open: `http://VM2_IP:8000` to see the blockchain explorer UI.

---

## Step 7: Enable mTLS (Production - Optional)

For production, enable mTLS between VMs.

### 7.1 Generate Certificates on VM 2

```bash
cd FYP-2/jumpserver-api/certs

# Generate server certificate
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout server-key.pem \
  -out server-cert.pem \
  -days 365 \
  -subj "/CN=jumpserver-api"

# Generate CA certificate (use this to sign client cert)
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout ca-key.pem \
  -out ca-cert.pem \
  -days 365 \
  -subj "/CN=FYP2-CA"

# Generate client certificate for JumpServer
openssl req -newkey rsa:4096 -nodes \
  -keyout jumpserver-client-key.pem \
  -out jumpserver-client.csr \
  -subj "/CN=jumpserver"

openssl x509 -req -in jumpserver-client.csr \
  -CA ca-cert.pem -CAkey ca-key.pem \
  -CAcreateserial -out jumpserver-client-cert.pem \
  -days 365
```

### 7.2 Copy Client Certificates to VM 1

```bash
# On VM 2
scp jumpserver-client-cert.pem user@VM1_IP:/home/user/test/certs/
scp jumpserver-client-key.pem user@VM1_IP:/home/user/test/certs/
scp ca-cert.pem user@VM1_IP:/home/user/test/certs/
```

### 7.3 Update Configurations

**VM 2** - Update `.env`:
```bash
cd FYP-2/jumpserver-api
nano .env
```

```env
TLS_KEY_PATH=./certs/server-key.pem
TLS_CERT_PATH=./certs/server-cert.pem
TLS_CA_PATH=./certs/ca-cert.pem
```

**VM 1** - Update `config.yml`:
```yaml
FABRIC_API_URL: "https://VM2_IP:3001"  # Note: HTTPS
FABRIC_CLIENT_CERT: "/home/user/test/certs/jumpserver-client-cert.pem"
FABRIC_CLIENT_KEY: "/home/user/test/certs/jumpserver-client-key.pem"
FABRIC_CA_CERT: "/home/user/test/certs/ca-cert.pem"
```

### 7.4 Restart Services

```bash
# VM 2: Restart API bridge
cd FYP-2/jumpserver-api
pm2 restart jumpserver-api  # or kill and restart

# VM 1: Restart Django
python manage.py runserver 0.0.0.0:8080
```

---

## Troubleshooting

### Problem: "Cannot connect to blockchain API"

**Check connectivity:**
```bash
# On VM 1
curl http://VM2_IP:3001/api/health
```

If timeout: Check firewall rules on VM 2:
```bash
# On VM 2
sudo ufw allow 3001/tcp
```

### Problem: "Evidence upload fails"

**Check API bridge logs:**
```bash
# On VM 2
cd FYP-2/jumpserver-api
cat logs/api.log  # if using PM2
# or check console output
```

Common causes:
- IPFS not running → Start IPFS cluster
- Fabric peer down → Restart blockchain
- File too large → Check IPFS limits

### Problem: "Transaction timeout"

Increase timeouts in `server.js`:
```javascript
submitOptions: () => ({ deadline: Date.now() + 60000 }),  // 60 seconds
```

---

## Summary

✅ **VM 2**: FYP-2 blockchain backend running with REST API bridge on port 3001

✅ **VM 1**: JumpServer configured to call VM 2's API for blockchain operations

✅ **Evidence Upload Flow**:
```
User → JumpServer → REST API (VM 2) → IPFS (get CID) → Fabric (append block)
```

✅ **Evidence Query Flow**:
```
User → JumpServer → REST API (VM 2) → Fabric (query chaincode) → Return data
```

✅ **Security**:
- Optional mTLS between VMs for production
- All Fabric communication uses gRPC + TLS
- IPFS private cluster (not public IPFS)

---

## Next Steps

1. **Test evidence upload** with various file types
2. **Test evidence query** and verification
3. **Test investigation dashboard** showing blockchain data
4. **Enable mTLS** for production deployment
5. **Set up monitoring** for API bridge and blockchain health

Need help with any step? Let me know!
