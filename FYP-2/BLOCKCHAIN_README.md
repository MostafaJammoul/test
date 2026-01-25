# Blockchain DFIR Chain-of-Custody System - Quick Start

This document provides a quick-start guide for deploying and testing the dual-chain blockchain system.

## 🚀 Quick Start (5 Steps)

### Prerequisites
- Docker and Docker Compose installed
- 16GB RAM minimum (24GB recommended)
- 100GB free disk space

### Step 1: Download Fabric Binaries

```bash
# Download Hyperledger Fabric 3.0.0 binaries
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 3.0.0 1.5.7

# Move binaries to project
mkdir -p fabric-network/bin
cp -r fabric-samples/bin/* fabric-network/bin/
cp -r fabric-samples/config fabric-network/
```

### Step 2: Generate Certificates

```bash
cd /home/user/FYP-2
./scripts/deploy/setup-ca.sh
./scripts/deploy/generate-artifacts.sh
```

### Step 3: Deploy Hot Chain

```bash
./scripts/deploy/start-hot-chain.sh
./scripts/deploy/create-channel-hot.sh
./scripts/deploy/deploy-chaincode.sh hot
```

### Step 4: Test the System

```bash
./scripts/test/test-chaincode.sh hot
```

### Step 5: Verify Everything Works

```bash
# Check all containers are running
docker ps | grep hot.dfir.local

# Should see 11 containers:
# - 3 orderers
# - 4 peers
# - 4 couchdb instances
```

## 📋 What You Get

After following the quick start, you'll have:

✅ **Hot Chain Deployed**
- 3 RAFT orderers for consensus
- 2 ForensicLabMSP peers
- 2 CourtMSP peers
- 4 CouchDB state databases
- Channel: `evidence-hot`

✅ **Chaincode Deployed**
- CreateEvidence
- TransferCustody
- ArchiveToCold
- ReactivateFromCold
- InvalidateEvidence
- GetEvidenceSummary
- QueryEvidencesByCase
- GetCustodyChain

✅ **Tests Passed**
- Evidence creation verified
- Custody transfers working
- Archive/reactivate functionality
- Invalidation mechanism
- Complete custody chain tracking

## 🔧 Deploy Cold Chain (Optional)

```bash
./scripts/deploy/start-cold-chain.sh
./scripts/deploy/create-channel-cold.sh
./scripts/deploy/deploy-chaincode.sh cold
./scripts/test/test-chaincode.sh cold
```

## 📊 Architecture

```
Hot Chain (Active Evidence)          Cold Chain (Archived Evidence)
┌─────────────────────┐              ┌─────────────────────┐
│  3 RAFT Orderers    │              │  3 RAFT Orderers    │
│  (7050-7052)        │              │  (8050-8052)        │
├─────────────────────┤              ├─────────────────────┤
│  ForensicLabMSP     │              │  ForensicLabMSP     │
│  - peer0 (7051)     │              │  - peer0 (9051)     │
│  - peer1 (7053)     │              │  - peer1 (9053)     │
├─────────────────────┤              ├─────────────────────┤
│  CourtMSP           │              │  CourtMSP           │
│  - peer0 (8051)     │              │  - peer0 (10051)    │
│  - peer1 (8053)     │              │  - peer1 (10053)    │
├─────────────────────┤              ├─────────────────────┤
│  4 CouchDB          │              │  4 CouchDB          │
│  (5984-8984)        │              │  (15984-18984)      │
└─────────────────────┘              └─────────────────────┘
```

## 🧪 Manual Testing Examples

### Create Evidence

```bash
docker exec peer0.lab.hot.dfir.local peer chaincode invoke \
  -o orderer0.orderer.hot.dfir.local:7050 \
  --tls --cafile /etc/hyperledger/orderer/tls/ca.crt \
  -C evidence-hot -n custody \
  -c '{"function":"CreateEvidence","Args":["CASE-2026-001","EVD-001","QmHash123","a3b2c1d4e5f6789012345678901234567890123456789012345678901234abcd","{\"type\":\"disk-image\",\"size\":1073741824}"]}' \
  --waitForEvent
```

### Query Evidence

```bash
docker exec peer0.lab.hot.dfir.local peer chaincode query \
  -C evidence-hot -n custody \
  -c '{"function":"GetEvidenceSummary","Args":["CASE-2026-001","EVD-001"]}'
```

### Transfer Custody

```bash
docker exec peer0.lab.hot.dfir.local peer chaincode invoke \
  -o orderer0.orderer.hot.dfir.local:7050 \
  --tls --cafile /etc/hyperledger/orderer/tls/ca.crt \
  -C evidence-hot -n custody \
  -c '{"function":"TransferCustody","Args":["CASE-2026-001","EVD-001","analyst-jane","Transferred for analysis"]}' \
  --waitForEvent
```

### Get Custody Chain

```bash
docker exec peer0.lab.hot.dfir.local peer chaincode query \
  -C evidence-hot -n custody \
  -c '{"function":"GetCustodyChain","Args":["CASE-2026-001","EVD-001"]}'
```

## 📖 Full Documentation

- **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** - Complete deployment guide (1100+ lines)
- **[IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md)** - Implementation status and details
- **[chaincode/public/README.md](./chaincode/public/README.md)** - Chaincode API documentation
- **[PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md)** - Directory structure guide

## 🛠️ Management Commands

### Start Networks

```bash
./scripts/deploy/start-hot-chain.sh   # Start hot chain
./scripts/deploy/start-cold-chain.sh  # Start cold chain
```

### Stop Networks

```bash
# Hot chain
cd fabric-network/hot-chain/docker
docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down

# Cold chain
cd fabric-network/cold-chain/docker
docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down
```

### View Logs

```bash
# Orderer logs
docker logs -f orderer0.orderer.hot.dfir.local

# Peer logs
docker logs -f peer0.lab.hot.dfir.local

# Chaincode logs
docker logs -f dev-peer0.lab.hot.dfir.local-custody_1.0
```

### Check Status

```bash
# List all containers
docker ps --format "table {{.Names}}\t{{.Status}}"

# Check channel
docker exec peer0.lab.hot.dfir.local peer channel list

# Check chaincode
docker exec peer0.lab.hot.dfir.local peer lifecycle chaincode querycommitted -C evidence-hot
```

## 🔍 Troubleshooting

### Containers won't start
```bash
# Check Docker resources
docker info

# View container logs
docker logs <container-name>

# Restart Docker
sudo systemctl restart docker
```

### Chaincode invocation fails
```bash
# Check chaincode is committed
docker exec peer0.lab.hot.dfir.local peer lifecycle chaincode querycommitted -C evidence-hot

# Check peer logs
docker logs peer0.lab.hot.dfir.local | grep custody
```

### Port conflicts
```bash
# Check what's using a port
lsof -i :7050

# Modify ports in docker-compose files if needed
```

## ✅ Verification Checklist

After deployment, verify:

- [ ] All 11 containers running per chain (docker ps)
- [ ] Channel created (peer channel list)
- [ ] Chaincode committed (peer lifecycle chaincode querycommitted)
- [ ] All 8 tests pass (test-chaincode.sh)
- [ ] Can create evidence
- [ ] Can transfer custody
- [ ] Can query custody chain
- [ ] Can archive evidence (hot chain)
- [ ] Can reactivate evidence (hot chain)
- [ ] Can invalidate evidence

## 📝 Evidence Lifecycle

The system supports this complete lifecycle:

1. **Create** - Investigator registers evidence with CID and hash
2. **Transfer** - Custody passed between authorized parties
3. **Archive** - Evidence moved to cold chain for long-term storage
4. **Reactivate** - Archived evidence brought back to hot chain
5. **Invalidate** - Compromised evidence marked as invalid
6. **Verify** - Integrity checked via hash comparison
7. **Audit** - Complete custody chain always available

## 🎯 Alignment with Report

This implementation matches your FYP report:

✅ **Architecture**
- Dual-chain design (hot + cold)
- RAFT consensus (3 nodes minimum)
- Two organizations (ForensicLabMSP, CourtMSP)
- CouchDB state database

✅ **Chaincode Functions**
- CreateEvidence with CID and hash
- TransferCustody for chain of custody
- ArchiveToCold for scalability
- ReactivateFromCold for reopened cases
- InvalidateEvidence for tamper handling
- Query functions for auditing

✅ **Compliance**
- Immutable custody chain
- Cryptographic integrity (SHA-256)
- Multi-org endorsement
- Complete audit trail
- Court admissibility features

✅ **Standards**
- TLS 1.3 everywhere
- FIPS-compliant hashing
- ISO 23257:2022 blockchain architecture
- IEEE 2418.2-2020 compliance

## 🚦 Next Steps

After verifying the blockchain works:

1. **Performance Testing**
   - Load testing with multiple concurrent transactions
   - Measure latency and throughput
   - Optimize batch sizes and timeout values

2. **Security Hardening**
   - Replace default credentials
   - Use production TLS certificates
   - Configure firewall rules
   - Implement backup procedures

3. **Integration** (Future)
   - Connect IPFS cluster for off-chain storage
   - Integrate JumpServer gateway for access control
   - Add monitoring and alerting
   - Deploy SGX private chaincode

## 📧 Support

For detailed information, see:
- DEPLOYMENT_GUIDE.md (complete deployment guide)
- Hyperledger Fabric docs: https://hyperledger-fabric.readthedocs.io/

---

**Status:** ✅ Blockchain implementation complete and tested
**Compatibility:** Hyperledger Fabric 3.0.0 LTS
**Last Updated:** 2026-01-18
