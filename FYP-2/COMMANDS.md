# Copy-Paste Commands for Fresh Kali Linux Installation

This file contains all commands you need to copy and paste to install and deploy the DFIR blockchain system on a fresh Kali Linux machine.

---

## 🚀 OPTION 1: Automated Installation (Easiest)

Just copy and paste these 3 commands:

```bash
# 1. Download and run installation script
curl -sSL https://raw.githubusercontent.com/omar-kaaki/FYP-2/claude/blockchain-dfir-implementation-HW9NU/scripts/setup/install-kali.sh > install.sh
bash install.sh

# 2. Activate docker group (REQUIRED after first installation)
newgrp docker

# 3. Deploy the blockchain
cd ~/FYP-2
./scripts/deploy/complete-setup.sh
```

**That's it!** The blockchain will be deployed and tested automatically.

---

## 📋 OPTION 2: Manual Installation (Step-by-Step)

If you want to see each step, copy and paste these commands one section at a time:

### A. Update System

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### B. Install Docker

```bash
# Install dependencies
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker
```

### C. Install Docker Compose

```bash
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version
```

### D. Install Go

```bash
# Download Go
wget https://go.dev/dl/go1.21.6.linux-amd64.tar.gz

# Install
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz
rm go1.21.6.linux-amd64.tar.gz

# Add to PATH
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
source ~/.bashrc

# Verify
go version
```

### E. Install Tools

```bash
sudo apt-get install -y git curl wget jq python3 python3-pip build-essential
```

### F. Clone Repository

```bash
cd ~
git clone https://github.com/omar-kaaki/FYP-2.git
cd FYP-2
git checkout claude/blockchain-dfir-implementation-HW9NU
```

### G. Download Fabric Binaries

```bash
cd ~/FYP-2

# Download Fabric
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 3.0.0 1.5.7 -s

# Copy binaries
mkdir -p fabric-network/bin
cp -r fabric-samples/bin/* fabric-network/bin/
cp -r fabric-samples/config fabric-network/
rm -rf fabric-samples
```

### H. Activate Docker Group (IMPORTANT!)

```bash
# MUST DO THIS before deploying blockchain
newgrp docker
```

### I. Deploy Blockchain - Automated

```bash
cd ~/FYP-2
./scripts/deploy/complete-setup.sh
```

### J. Deploy Blockchain - Manual (Alternative)

```bash
cd ~/FYP-2

# Generate certificates
./scripts/deploy/setup-ca.sh

# Generate genesis blocks
./scripts/deploy/generate-artifacts.sh

# Start hot chain
./scripts/deploy/start-hot-chain.sh

# Create channel
./scripts/deploy/create-channel-hot.sh

# Deploy chaincode
./scripts/deploy/deploy-chaincode.sh hot

# Test everything
./scripts/test/test-chaincode.sh hot
```

---

## ✅ Verify Installation

Copy and paste these to verify everything is working:

```bash
# Check Docker is running
docker ps

# Should see 11 containers:
# - 3 orderers
# - 4 peers
# - 4 couchdb

# Check blockchain channel
docker exec peer0.lab.hot.dfir.local peer channel list
# Should show: evidence-hot

# Check chaincode
docker exec peer0.lab.hot.dfir.local peer lifecycle chaincode querycommitted -C evidence-hot
# Should show: custody version 1.0
```

---

## 🧪 Test the Blockchain

Copy and paste to create and query evidence:

### Create Evidence

```bash
docker exec peer0.lab.hot.dfir.local peer chaincode invoke \
  -o orderer0.orderer.hot.dfir.local:7050 \
  --tls \
  --cafile /etc/hyperledger/orderer/tls/ca.crt \
  -C evidence-hot \
  -n custody \
  -c '{"function":"CreateEvidence","Args":["CASE-2026-001","EVD-001","QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG","a3b2c1d4e5f6789012345678901234567890123456789012345678901234abcd","{\"type\":\"disk-image\",\"size\":1073741824,\"collected\":\"2026-01-18\"}"]}' \
  --waitForEvent
```

### Query Evidence

```bash
docker exec peer0.lab.hot.dfir.local peer chaincode query \
  -C evidence-hot \
  -n custody \
  -c '{"function":"GetEvidenceSummary","Args":["CASE-2026-001","EVD-001"]}'
```

### Transfer Custody

```bash
docker exec peer0.lab.hot.dfir.local peer chaincode invoke \
  -o orderer0.orderer.hot.dfir.local:7050 \
  --tls \
  --cafile /etc/hyperledger/orderer/tls/ca.crt \
  -C evidence-hot \
  -n custody \
  -c '{"function":"TransferCustody","Args":["CASE-2026-001","EVD-001","analyst-jane","Transferred for forensic analysis"]}' \
  --waitForEvent
```

### Get Custody Chain

```bash
docker exec peer0.lab.hot.dfir.local peer chaincode query \
  -C evidence-hot \
  -n custody \
  -c '{"function":"GetCustodyChain","Args":["CASE-2026-001","EVD-001"]}'
```

---

## 🔍 View Logs

```bash
# Orderer logs
docker logs -f orderer0.orderer.hot.dfir.local

# Peer logs
docker logs -f peer0.lab.hot.dfir.local

# Chaincode logs
docker logs -f $(docker ps -q --filter name=dev-peer0.lab.hot)
```

---

## 🛑 Stop the Blockchain

```bash
cd ~/FYP-2/fabric-network/hot-chain/docker
docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down
```

---

## 🔄 Restart the Blockchain

```bash
cd ~/FYP-2/fabric-network/hot-chain/docker
docker-compose -f docker-compose-orderers.yaml up -d
docker-compose -f docker-compose-peers.yaml up -d

# Wait 30 seconds, then verify
docker ps
```

---

## 🧹 Clean Everything (Start Fresh)

**WARNING: This deletes all blockchain data!**

```bash
# Stop all containers
cd ~/FYP-2/fabric-network/hot-chain/docker
docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down -v

# Remove chaincode packages
cd ~/FYP-2
rm -rf chaincode-packages/

# Remove crypto materials
rm -rf fabric-network/hot-chain/crypto-config/
rm -rf fabric-network/hot-chain/channel-artifacts/

# Then run deployment again
./scripts/deploy/complete-setup.sh
```

---

## 🌐 Access CouchDB UI

Open in your browser:

```
Hot Chain:
- Lab Peer 0:   http://localhost:5984/_utils
- Lab Peer 1:   http://localhost:6984/_utils
- Court Peer 0: http://localhost:7984/_utils
- Court Peer 1: http://localhost:8984/_utils

Username: admin
Password: adminpw
```

---

## 📊 Check System Resources

```bash
# Check Docker disk usage
docker system df

# Check container resource usage
docker stats

# Check host resources
free -h
df -h
```

---

## 🔧 Common Issues and Fixes

### "Permission denied" error

```bash
# Solution: Activate docker group
newgrp docker

# Or log out and log back in
```

### "Port already in use"

```bash
# Find what's using the port
sudo lsof -i :7050

# Kill the process
sudo kill -9 <PID>
```

### "Cannot connect to Docker daemon"

```bash
# Start Docker
sudo systemctl start docker

# Enable auto-start
sudo systemctl enable docker
```

### Out of disk space

```bash
# Clean up Docker
docker system prune -a --volumes

# Remove old images
docker image prune -a
```

---

## 📚 Documentation

```bash
# View documentation
cd ~/FYP-2

# Quick start guide
cat BLOCKCHAIN_README.md

# Complete deployment guide
cat DEPLOYMENT_GUIDE.md

# Chaincode API
cat chaincode/public/README.md
```

---

## ⚡ Quick Command Summary

```bash
# Install everything
curl -sSL https://raw.githubusercontent.com/omar-kaaki/FYP-2/claude/blockchain-dfir-implementation-HW9NU/scripts/setup/install-kali.sh > install.sh && bash install.sh

# Activate docker
newgrp docker

# Deploy blockchain
cd ~/FYP-2 && ./scripts/deploy/complete-setup.sh

# Check status
docker ps

# View logs
docker logs -f peer0.lab.hot.dfir.local

# Stop blockchain
cd ~/FYP-2/fabric-network/hot-chain/docker && docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down
```

---

**All commands tested on:** Kali Linux 2023.x
**Last updated:** 2026-01-18
