# Quick Start Guide - JumpServer mTLS Integration

## One-Time Setup (5 minutes)

### On VM 2 (Blockchain):

```bash
cd /path/to/FYP-2/jumpserver-api

# 1. Generate mTLS certificates
./setup-mtls.sh

# 2. Start API bridge
./start.sh

# 3. Test mTLS locally
./test-mtls.sh

# 4. Copy client certificates to VM 1
scp -r client-certs/ user@VM1_IP:/home/user/test/certs/
```

### On VM 1 (JumpServer):

```bash
cd /home/user/test

# 1. Update config.yml
nano config.yml
```

Add:
```yaml
FABRIC_API_URL: "https://VM2_IP:3001"
FABRIC_USE_REST: true
FABRIC_CLIENT_CERT: "/home/user/test/certs/jumpserver-client-cert.pem"
FABRIC_CLIENT_KEY: "/home/user/test/certs/jumpserver-client-key.pem"
FABRIC_CA_CERT: "/home/user/test/certs/ca-cert.pem"
```

```bash
# 2. Update Django settings
nano apps/jumpserver/settings/base.py
```

Add at end:
```python
# FYP-2 Blockchain Configuration
FABRIC_API_URL = CONFIG.FABRIC_API_URL
FABRIC_USE_REST = CONFIG.get('FABRIC_USE_REST', True)
FABRIC_CLIENT_CERT = CONFIG.get('FABRIC_CLIENT_CERT')
FABRIC_CLIENT_KEY = CONFIG.get('FABRIC_CLIENT_KEY')
FABRIC_CA_CERT = CONFIG.get('FABRIC_CA_CERT')
```

```bash
# 3. Test connection
curl --cert /home/user/test/certs/jumpserver-client-cert.pem \
     --key /home/user/test/certs/jumpserver-client-key.pem \
     --cacert /home/user/test/certs/ca-cert.pem \
     https://VM2_IP:3001/api/health

# 4. Restart Django
cd /home/user/test/apps
python manage.py runserver 0.0.0.0:8080
```

## Daily Operations

### Start Services

**VM 2:**
```bash
cd /path/to/FYP-2/jumpserver-api
./start.sh
```

**VM 1:**
```bash
cd /home/user/test/apps
python manage.py runserver 0.0.0.0:8080
```

### Check Status

**VM 2:**
```bash
# API bridge health
curl --cert client-certs/jumpserver-client-cert.pem \
     --key client-certs/jumpserver-client-key.pem \
     --cacert client-certs/ca-cert.pem \
     https://localhost:3001/api/health

# Blockchain status
cd /path/to/FYP-2
bash check-blockchain-status.sh
```

### Test Evidence Upload

**VM 1 - Django shell:**
```bash
cd /home/user/test/apps
python manage.py shell
```

```python
from blockchain.clients.fabric_client import FabricClient

client = FabricClient()

# Health check
print(client.health_check())

# Upload test evidence
result = client.append_evidence(
    case_id='test-case-001',
    evidence_id='test-evidence-001',
    file_data=b'Test evidence data',
    file_hash='sha256:abc123',
    metadata={'type': 'test'},
    user_identifier='admin'
)

print(result)
# Should show: {'success': True, 'cid': 'Qm...', 'tx_id': '...'}

# Query evidence
evidence = client.query_evidence('test-evidence-001')
print(evidence)
```

## Troubleshooting

### Connection Failed

**Check firewall on VM 2:**
```bash
sudo ufw allow 3001/tcp
sudo ufw status
```

**Check API bridge is running:**
```bash
ps aux | grep node
netstat -tlnp | grep 3001
```

### Certificate Errors

**Verify certificates:**
```bash
cd /path/to/FYP-2/jumpserver-api
openssl verify -CAfile certs/ca-cert.pem certs/server-cert.pem
openssl verify -CAfile client-certs/ca-cert.pem client-certs/jumpserver-client-cert.pem
```

**Check permissions:**
```bash
chmod 600 certs/server-key.pem client-certs/jumpserver-client-key.pem
chmod 644 certs/*.pem client-certs/*.pem
```

**Regenerate if needed:**
```bash
./setup-mtls.sh
```

### Blockchain Not Running

**VM 2:**
```bash
cd /path/to/FYP-2/blockchain
./start-all.sh

cd ../ipfs/scripts
./start-ipfs-cluster.sh
```

## Key Files

### VM 2 (Blockchain)
```
FYP-2/jumpserver-api/
├── setup-mtls.sh         # Generate certificates
├── start.sh              # Start API bridge
├── test-mtls.sh          # Test mTLS connection
├── server.js             # API bridge code
├── .env                  # Configuration
├── certs/                # Server certificates
│   ├── ca-cert.pem
│   ├── server-cert.pem
│   └── server-key.pem
└── client-certs/         # Client certificates (copy to VM 1)
    ├── ca-cert.pem
    ├── jumpserver-client-cert.pem
    └── jumpserver-client-key.pem
```

### VM 1 (JumpServer)
```
/home/user/test/
├── config.yml                              # Main config
├── apps/
│   ├── jumpserver/settings/base.py        # Django settings
│   └── blockchain/clients/
│       └── fabric_client.py               # REST client
└── certs/                                  # Client certificates (from VM 2)
    ├── ca-cert.pem
    ├── jumpserver-client-cert.pem
    └── jumpserver-client-key.pem
```

## Security Checklist

- [ ] mTLS certificates generated
- [ ] Server certificate installed on VM 2
- [ ] Client certificates copied to VM 1
- [ ] Firewall configured (port 3001)
- [ ] HTTPS (not HTTP) enabled on API bridge
- [ ] Client certificate validation enabled
- [ ] Certificate permissions set correctly (600 for keys, 644 for certs)
- [ ] Test connection successful

## Next Steps

After setup is complete:
1. Test evidence upload from JumpServer UI
2. Verify evidence appears on blockchain
3. Check IPFS CID is stored correctly
4. Test investigation dashboard shows blockchain data
5. Monitor logs for any errors
6. Set up certificate expiration monitoring (90 days)

## Support

For detailed documentation, see:
- `README-MTLS.md` - Complete mTLS setup guide
- `JUMPSERVER_FYP2_INTEGRATION.md` - Full integration guide
- `FYP-2/jumpserver/README.md` - JumpServer documentation
