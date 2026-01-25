### Blockchain Deployment Guide - DFIR Chain-of-Custody System

This guide provides step-by-step instructions for deploying the dual-chain blockchain network for digital forensic evidence management.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Deployment Steps](#deployment-steps)
4. [Testing](#testing)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)
7. [Management Commands](#management-commands)

---

## Prerequisites

### Required Software

1. **Docker** (version 20.10+)
   ```bash
   docker --version
   ```

2. **Docker Compose** (version 1.29+)
   ```bash
   docker-compose --version
   ```

3. **Hyperledger Fabric Binaries** (version 3.0.0)
   ```bash
   # Download Fabric binaries
   curl -sSL https://bit.ly/2ysbOFE | bash -s -- 3.0.0 1.5.7

   # Move binaries to project
   mkdir -p fabric-network/bin
   cp -r fabric-samples/bin/* fabric-network/bin/
   cp -r fabric-samples/config fabric-network/
   ```

4. **Go** (version 1.21+) - for chaincode compilation
   ```bash
   go version
   ```

### System Requirements

**Hot Chain:**
- CPU: 8 cores minimum (12 recommended)
- RAM: 16GB minimum (24GB recommended)
- Disk: 50GB available (SSD recommended)
- Network: 100 Mbps

**Cold Chain:**
- CPU: 4 cores minimum (8 recommended)
- RAM: 8GB minimum (16GB recommended)
- Disk: 50GB available
- Network: 100 Mbps

**Total (Both Chains):**
- CPU: 12 cores minimum (20 recommended)
- RAM: 24GB minimum (40GB recommended)
- Disk: 100GB available
- Network: 1 Gbps recommended

---

## Architecture Overview

### Dual-Chain Design

The system implements two separate Hyperledger Fabric networks:

1. **Hot Chain** - Active Investigations
   - Channel: `evidence-hot`
   - 3 RAFT orderers (ports 7050-7052)
   - 4 peers: 2 ForensicLabMSP + 2 CourtMSP
   - 4 CouchDB instances
   - Purpose: Active evidence handling, custody transfers

2. **Cold Chain** - Archived Evidence
   - Channel: `evidence-cold`
   - 3 RAFT orderers (ports 8050-8052)
   - 4 peers: 2 ForensicLabMSP + 2 CourtMSP
   - 4 CouchDB instances
   - Purpose: Long-term archive storage, append-only

### Organizations

1. **OrdererOrg**: Manages consensus nodes
2. **ForensicLabMSP**: Forensic laboratory organization
3. **CourtMSP**: Court/judicial organization

### Components

- **Orderers**: RAFT consensus (3 nodes per chain for fault tolerance)
- **Peers**: Execute chaincode, maintain ledger (2 per org per chain)
- **CouchDB**: JSON state database for rich queries
- **Chaincode**: Smart contracts for evidence custody operations

---

## Deployment Steps

Follow these steps in order to deploy the complete system.

### Step 1: Generate Crypto Materials

Generate certificates and keys for all network participants.

```bash
cd /home/user/FYP-2
./scripts/deploy/setup-ca.sh
```

**What this does:**
- Generates crypto materials for all organizations
- Creates MSP structures
- Generates TLS certificates
- Sets proper permissions

**Expected output:**
```
========================================
CA Setup Complete
========================================

Hot Chain crypto materials: .../fabric-network/hot-chain/crypto-config
Cold Chain crypto materials: .../fabric-network/cold-chain/crypto-config

Organizations configured:
  - OrdererOrg (3 orderers per chain)
  - ForensicLabMSP (2 peers per chain, 5 users for hot, 3 for cold)
  - CourtMSP (2 peers per chain, 3 users per chain)
```

**Verify:**
```bash
ls -la fabric-network/hot-chain/crypto-config/
ls -la fabric-network/cold-chain/crypto-config/
```

---

### Step 2: Generate Channel Artifacts

Create genesis blocks and channel configuration transactions.

```bash
./scripts/deploy/generate-artifacts.sh
```

**What this does:**
- Generates genesis blocks for orderers
- Creates channel creation transactions
- Generates anchor peer update transactions
- Creates inspection files for verification

**Expected output:**
```
========================================
Artifact Generation Complete
========================================

Hot Chain Artifacts:
  - Genesis Block: fabric-network/hot-chain/channel-artifacts/genesis.block
  - Channel TX: fabric-network/hot-chain/channel-artifacts/evidence-hot.tx

Cold Chain Artifacts:
  - Genesis Block: fabric-network/cold-chain/channel-artifacts/genesis.block
  - Channel TX: fabric-network/cold-chain/channel-artifacts/evidence-cold.tx
```

**Verify:**
```bash
ls -la fabric-network/hot-chain/channel-artifacts/
ls -la fabric-network/cold-chain/channel-artifacts/
```

---

### Step 3: Start Hot Chain Network

Deploy the hot chain for active investigations.

```bash
./scripts/deploy/start-hot-chain.sh
```

**What this does:**
- Starts 3 RAFT orderers
- Starts 4 peers (2 ForensicLabMSP + 2 CourtMSP)
- Starts 4 CouchDB instances
- Verifies all containers are running

**Expected output:**
```
========================================
Hot Chain Network Started Successfully
========================================

Orderers (RAFT Consensus):
  - orderer0.orderer.hot.dfir.local:7050
  - orderer1.orderer.hot.dfir.local:7051
  - orderer2.orderer.hot.dfir.local:7052

ForensicLabMSP Peers:
  - peer0.lab.hot.dfir.local:7051
  - peer1.lab.hot.dfir.local:7053

CourtMSP Peers:
  - peer0.court.hot.dfir.local:8051
  - peer1.court.hot.dfir.local:8053
```

**Verify:**
```bash
docker ps | grep hot.dfir.local
# Should show 11 containers (3 orderers + 4 peers + 4 couchdb)
```

---

### Step 4: Create Hot Chain Channel

Create the `evidence-hot` channel and join all peers.

```bash
./scripts/deploy/create-channel-hot.sh
```

**What this does:**
- Creates the `evidence-hot` channel
- Joins all ForensicLabMSP peers
- Joins all CourtMSP peers
- Updates anchor peers for both organizations

**Expected output:**
```
========================================
Channel Created Successfully
========================================

Channel: evidence-hot

Joined Peers:
  ForensicLabMSP:
    - peer0.lab.hot.dfir.local:7051
    - peer1.lab.hot.dfir.local:7053
  CourtMSP:
    - peer0.court.hot.dfir.local:8051
    - peer1.court.hot.dfir.local:8053
```

**Verify:**
```bash
docker exec peer0.lab.hot.dfir.local peer channel list
# Should show: evidence-hot
```

---

### Step 5: Deploy Chaincode to Hot Chain

Package, install, approve, and commit the custody chaincode.

```bash
./scripts/deploy/deploy-chaincode.sh hot
```

**What this does:**
- Packages the chaincode (Go smart contract)
- Installs on all peers
- Approves for both organizations
- Commits the chaincode definition
- Initializes the chaincode

**Expected output:**
```
========================================
Chaincode Deployed Successfully
========================================

Deployment Summary:
  Chain: hot
  Channel: evidence-hot
  Chaincode: custody
  Version: 1.0

Installed on peers:
  ForensicLabMSP:
    - peer0.lab.hot.dfir.local
    - peer1.lab.hot.dfir.local
  CourtMSP:
    - peer0.court.hot.dfir.local
    - peer1.court.hot.dfir.local
```

**Verify:**
```bash
docker exec peer0.lab.hot.dfir.local peer lifecycle chaincode querycommitted -C evidence-hot
# Should show: custody version 1.0
```

---

### Step 6: Test Hot Chain Chaincode

Run comprehensive tests on the deployed chaincode.

```bash
./scripts/test/test-chaincode.sh hot
```

**What this does:**
- Tests CreateEvidence function
- Tests TransferCustody function
- Tests ArchiveToCold function
- Tests ReactivateFromCold function
- Tests InvalidateEvidence function
- Tests query functions
- Demonstrates complete evidence lifecycle

**Expected output:**
```
========================================
Test Summary
========================================

All tests completed on hot chain

Tests Executed:
  ✓ CreateEvidence
  ✓ GetEvidenceSummary
  ✓ TransferCustody
  ✓ GetCustodyChain
  ✓ QueryEvidencesByCase
  ✓ ArchiveToCold
  ✓ ReactivateFromCold
  ✓ InvalidateEvidence

All tests passed successfully!
```

---

### Step 7: Start Cold Chain Network (Optional)

Deploy the cold chain for archived evidence.

```bash
./scripts/deploy/start-cold-chain.sh
```

**What this does:**
- Starts 3 RAFT orderers for cold chain
- Starts 4 peers (2 ForensicLabMSP + 2 CourtMSP)
- Starts 4 CouchDB instances
- Verifies all containers are running

**Expected output:**
```
========================================
Cold Chain Network Started Successfully
========================================

Orderers (RAFT Consensus):
  - orderer0.orderer.cold.dfir.local:8050
  - orderer1.orderer.cold.dfir.local:8051
  - orderer2.orderer.cold.dfir.local:8052
```

**Verify:**
```bash
docker ps | grep cold.dfir.local
# Should show 11 containers
```

---

### Step 8: Create Cold Chain Channel (Optional)

Create the `evidence-cold` channel and join all peers.

```bash
./scripts/deploy/create-channel-cold.sh
```

**Expected output:**
```
========================================
Channel Created Successfully
========================================

Channel: evidence-cold

Joined Peers:
  ForensicLabMSP:
    - peer0.lab.cold.dfir.local:9051
    - peer1.lab.cold.dfir.local:9053
  CourtMSP:
    - peer0.court.cold.dfir.local:10051
    - peer1.court.cold.dfir.local:10053
```

---

### Step 9: Deploy Chaincode to Cold Chain (Optional)

```bash
./scripts/deploy/deploy-chaincode.sh cold
```

**Expected output:**
```
========================================
Chaincode Deployed Successfully
========================================

Deployment Summary:
  Chain: cold
  Channel: evidence-cold
  Chaincode: custody
  Version: 1.0
```

---

### Step 10: Test Cold Chain Chaincode (Optional)

```bash
./scripts/test/test-chaincode.sh cold
```

---

## Testing

### Manual Testing

You can also invoke chaincode functions manually:

#### Create Evidence

```bash
docker exec peer0.lab.hot.dfir.local peer chaincode invoke \
  -o orderer0.orderer.hot.dfir.local:7050 \
  --tls \
  --cafile /etc/hyperledger/orderer/tls/ca.crt \
  -C evidence-hot \
  -n custody \
  -c '{"function":"CreateEvidence","Args":["CASE-001","EVD-001","QmHash123","a3b2c1d4e5f6789012345678901234567890123456789012345678901234abcd","{\"type\":\"disk-image\"}"]}' \
  --waitForEvent
```

#### Query Evidence

```bash
docker exec peer0.lab.hot.dfir.local peer chaincode query \
  -C evidence-hot \
  -n custody \
  -c '{"function":"GetEvidenceSummary","Args":["CASE-001","EVD-001"]}'
```

#### Transfer Custody

```bash
docker exec peer0.lab.hot.dfir.local peer chaincode invoke \
  -o orderer0.orderer.hot.dfir.local:7050 \
  --tls \
  --cafile /etc/hyperledger/orderer/tls/ca.crt \
  -C evidence-hot \
  -n custody \
  -c '{"function":"TransferCustody","Args":["CASE-001","EVD-001","analyst-john","Transferred for analysis"]}' \
  --waitForEvent
```

#### Get Custody Chain

```bash
docker exec peer0.lab.hot.dfir.local peer chaincode query \
  -C evidence-hot \
  -n custody \
  -c '{"function":"GetCustodyChain","Args":["CASE-001","EVD-001"]}'
```

---

## Verification

### Check Network Status

```bash
# View all running containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check orderer logs
docker logs orderer0.orderer.hot.dfir.local

# Check peer logs
docker logs peer0.lab.hot.dfir.local

# Check CouchDB
curl -X GET http://localhost:5984/_all_dbs
```

### Check Channel Information

```bash
# List channels
docker exec peer0.lab.hot.dfir.local peer channel list

# Get channel info
docker exec peer0.lab.hot.dfir.local peer channel getinfo -c evidence-hot
```

### Check Chaincode

```bash
# Query committed chaincode
docker exec peer0.lab.hot.dfir.local peer lifecycle chaincode querycommitted -C evidence-hot

# Query installed chaincode
docker exec peer0.lab.hot.dfir.local peer lifecycle chaincode queryinstalled
```

---

## Troubleshooting

### Container Not Starting

```bash
# View container logs
docker logs <container-name>

# Check Docker resources
docker info

# Restart container
docker restart <container-name>
```

### Chaincode Invocation Fails

```bash
# Check peer logs
docker logs peer0.lab.hot.dfir.local | grep custody

# Check chaincode container logs
docker logs dev-peer0.lab.hot.dfir.local-custody_1.0

# Verify chaincode is committed
docker exec peer0.lab.hot.dfir.local peer lifecycle chaincode querycommitted -C evidence-hot -n custody
```

### Channel Not Found

```bash
# List channels on peer
docker exec peer0.lab.hot.dfir.local peer channel list

# Re-join channel if needed
docker exec peer0.lab.hot.dfir.local peer channel join \
  -b /etc/hyperledger/channel-artifacts/evidence-hot.block
```

### Endorsement Policy Error

This usually means not all required organizations have approved the chaincode.

```bash
# Check approval status
docker exec peer0.lab.hot.dfir.local peer lifecycle chaincode checkcommitreadiness \
  --channelID evidence-hot \
  --name custody \
  --version 1.0 \
  --sequence 1

# Re-approve if needed
# (See deploy-chaincode.sh for approval commands)
```

### Port Conflicts

If ports are already in use:

```bash
# Check what's using a port
lsof -i :7050

# Stop conflicting service or modify docker-compose files to use different ports
```

---

## Management Commands

### Start Networks

```bash
# Start hot chain
./scripts/deploy/start-hot-chain.sh

# Start cold chain
./scripts/deploy/start-cold-chain.sh
```

### Stop Networks

```bash
# Stop hot chain
cd fabric-network/hot-chain/docker
docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down

# Stop cold chain
cd fabric-network/cold-chain/docker
docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down
```

### Clean Up (Remove All Data)

**WARNING: This deletes all blockchain data!**

```bash
# Stop and remove hot chain
cd fabric-network/hot-chain/docker
docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down -v

# Stop and remove cold chain
cd fabric-network/cold-chain/docker
docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down -v

# Remove chaincode packages
rm -rf chaincode-packages/
```

### View Logs

```bash
# Follow logs for a container
docker logs -f <container-name>

# View last 100 lines
docker logs --tail 100 <container-name>

# View logs since a specific time
docker logs --since 10m <container-name>
```

### Query CouchDB Directly

```bash
# List all databases
curl -X GET http://admin:adminpw@localhost:5984/_all_dbs

# Query evidence-hot database
curl -X GET http://admin:adminpw@localhost:5984/evidence-hot/_all_docs

# Get specific evidence record
curl -X GET http://admin:adminpw@localhost:5984/evidence-hot/<doc-id>
```

---

## Complete Deployment Example

Here's the complete sequence to deploy both chains:

```bash
# 1. Generate crypto materials
./scripts/deploy/setup-ca.sh

# 2. Generate channel artifacts
./scripts/deploy/generate-artifacts.sh

# 3. Deploy hot chain
./scripts/deploy/start-hot-chain.sh
./scripts/deploy/create-channel-hot.sh
./scripts/deploy/deploy-chaincode.sh hot

# 4. Test hot chain
./scripts/test/test-chaincode.sh hot

# 5. Deploy cold chain
./scripts/deploy/start-cold-chain.sh
./scripts/deploy/create-channel-cold.sh
./scripts/deploy/deploy-chaincode.sh cold

# 6. Test cold chain
./scripts/test/test-chaincode.sh cold

# 7. Verify everything is running
docker ps
```

---

## Next Steps

After successful deployment:

1. **Integrate with External Systems**
   - Connect JumpServer gateway (when ready)
   - Integrate IPFS cluster (when ready)
   - Set up monitoring and alerting

2. **Security Hardening**
   - Change default credentials
   - Configure firewall rules
   - Set up TLS certificates from trusted CA
   - Implement backup procedures

3. **Performance Tuning**
   - Adjust batch sizes based on load
   - Optimize CouchDB indexes
   - Configure peer caching
   - Tune RAFT parameters

4. **Monitoring**
   - Set up Prometheus for metrics
   - Configure Grafana dashboards
   - Implement log aggregation
   - Set up alerting rules

---

## Support

For issues or questions:

1. Check logs: `docker logs <container-name>`
2. Verify prerequisites are met
3. Review troubleshooting section
4. Check Hyperledger Fabric documentation: https://hyperledger-fabric.readthedocs.io/

---

**Deployment Guide Version:** 1.0
**Last Updated:** 2026-01-18
**Compatible with:** Hyperledger Fabric 3.0.0 LTS
