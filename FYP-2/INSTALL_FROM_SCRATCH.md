# Install DFIR Blockchain on Fresh Kali Linux

This guide shows you how to install and deploy the complete DFIR blockchain system on a fresh Kali Linux installation.

## 🚀 One-Command Installation

Run this single command on your fresh Kali system:

```bash
curl -sSL https://raw.githubusercontent.com/omar-kaaki/FYP-2/claude/blockchain-dfir-implementation-HW9NU/scripts/setup/install-kali.sh | bash
```

This will:
1. ✅ Update your system
2. ✅ Install Docker and Docker Compose
3. ✅ Install Go 1.21
4. ✅ Install all required tools
5. ✅ Clone this repository to ~/FYP-2
6. ✅ Download Hyperledger Fabric binaries
7. ✅ Set up all permissions

**Time:** ~10 minutes

---

## 📋 Manual Installation (Step-by-Step)

If you prefer to do it manually, follow these steps:

### Step 1: Install Docker

```bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install dependencies
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
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

### Step 2: Install Docker Compose

```bash
# Install Docker Compose standalone
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

### Step 3: Install Go

```bash
# Download Go 1.21
wget https://go.dev/dl/go1.21.6.linux-amd64.tar.gz

# Install Go
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz
rm go1.21.6.linux-amd64.tar.gz

# Add to PATH
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
source ~/.bashrc

# Verify installation
go version
```

### Step 4: Install Additional Tools

```bash
sudo apt-get install -y git curl wget jq python3 python3-pip build-essential
```

### Step 5: Clone Repository

```bash
cd ~
git clone https://github.com/omar-kaaki/FYP-2.git
cd FYP-2
git checkout claude/blockchain-dfir-implementation-HW9NU
```

### Step 6: Download Fabric Binaries

```bash
cd ~/FYP-2

# Download Fabric binaries
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 3.0.0 1.5.7 -s

# Copy binaries to project
mkdir -p fabric-network/bin
cp -r fabric-samples/bin/* fabric-network/bin/
cp -r fabric-samples/config fabric-network/
rm -rf fabric-samples
```

### Step 7: Activate Docker Group

```bash
# IMPORTANT: You must activate docker group membership
# Option 1: Quick activation (for current session)
newgrp docker

# Option 2: Log out and log back in (recommended)
# This ensures docker group is active for all future sessions
```

---

## 🎯 Deploy the Blockchain

After installation, deploy the blockchain:

### Option 1: Automated Deployment (Recommended)

```bash
cd ~/FYP-2
./scripts/deploy/complete-setup.sh
```

This will:
1. Generate all certificates
2. Create genesis blocks
3. Start hot chain network
4. Create channel and deploy chaincode
5. Run comprehensive tests
6. Optionally deploy cold chain

**Time:** ~10 minutes

### Option 2: Manual Step-by-Step

```bash
cd ~/FYP-2

# 1. Generate crypto materials
./scripts/deploy/setup-ca.sh

# 2. Generate channel artifacts
./scripts/deploy/generate-artifacts.sh

# 3. Start hot chain
./scripts/deploy/start-hot-chain.sh

# 4. Create channel
./scripts/deploy/create-channel-hot.sh

# 5. Deploy chaincode
./scripts/deploy/deploy-chaincode.sh hot

# 6. Test the system
./scripts/test/test-chaincode.sh hot
```

---

## ✅ Verify Installation

After deployment, verify everything is working:

```bash
# Check all containers are running
docker ps

# You should see 11 containers for hot chain:
# - 3 orderers (orderer0, orderer1, orderer2)
# - 4 peers (2 lab, 2 court)
# - 4 couchdb instances

# Test a query
docker exec peer0.lab.hot.dfir.local peer channel list
# Should show: evidence-hot

# Check chaincode
docker exec peer0.lab.hot.dfir.local peer lifecycle chaincode querycommitted -C evidence-hot
# Should show: custody version 1.0
```

---

## 🐛 Troubleshooting

### Docker Permission Denied

If you get "permission denied" errors:

```bash
# Activate docker group
newgrp docker

# Or log out and log back in
```

### Port Already in Use

If ports are already in use:

```bash
# Check what's using the port
sudo lsof -i :7050

# Kill the process or change ports in docker-compose files
```

### Containers Won't Start

```bash
# Check Docker is running
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# View container logs
docker logs <container-name>
```

### Out of Memory

```bash
# Check Docker resources
docker info

# Clean up old containers and images
docker system prune -a
```

---

## 📊 System Requirements

### Minimum Requirements
- **CPU:** 4 cores
- **RAM:** 8 GB
- **Disk:** 50 GB free
- **OS:** Kali Linux (Debian-based)

### Recommended Requirements
- **CPU:** 8+ cores
- **RAM:** 16 GB
- **Disk:** 100 GB free (SSD)
- **Network:** Stable internet connection

---

## 🔍 What Gets Installed

### Software
- Docker 24.x
- Docker Compose 2.x
- Go 1.21.6
- Git, curl, wget, jq
- Python 3 with pip
- Build tools (gcc, make, etc.)

### Hyperledger Fabric
- Fabric binaries 3.0.0
- Fabric CA 1.5.7
- configtxgen, peer, orderer tools

### Project Files
- Location: `~/FYP-2`
- Chaincode: Go smart contracts
- Docker configs: Network definitions
- Scripts: Deployment and testing
- Documentation: Complete guides

---

## 📚 Quick Reference

### Key Locations
```
~/FYP-2/                           # Project root
├── fabric-network/                # Blockchain networks
│   ├── hot-chain/                # Active investigations
│   └── cold-chain/               # Archived evidence
├── chaincode/public/             # Smart contracts
├── scripts/
│   ├── deploy/                   # Deployment scripts
│   └── test/                     # Testing scripts
└── docs/                         # Documentation
```

### Important Scripts
```bash
# Installation
~/FYP-2/scripts/setup/install-kali.sh      # Complete installation

# Deployment
~/FYP-2/scripts/deploy/complete-setup.sh   # Complete deployment
~/FYP-2/scripts/deploy/start-hot-chain.sh  # Start hot chain
~/FYP-2/scripts/deploy/deploy-chaincode.sh # Deploy smart contract

# Testing
~/FYP-2/scripts/test/test-chaincode.sh     # Test all functions
```

### Documentation
```bash
# Quick start
~/FYP-2/BLOCKCHAIN_README.md

# Complete deployment guide
~/FYP-2/DEPLOYMENT_GUIDE.md

# Chaincode API reference
~/FYP-2/chaincode/public/README.md

# Implementation details
~/FYP-2/IMPLEMENTATION_STATUS.md
```

---

## 🎓 Next Steps

After successful installation:

1. **Explore the System**
   - Review the test results
   - Check container logs
   - Query CouchDB (http://localhost:5984/_utils)

2. **Create Your Own Evidence**
   - Use the manual commands in BLOCKCHAIN_README.md
   - Test the complete lifecycle
   - Verify custody chain tracking

3. **Customize**
   - Modify chaincode for your use case
   - Adjust network configurations
   - Add monitoring and logging

4. **Production Preparation**
   - Security hardening
   - Performance tuning
   - Backup procedures
   - Integration with external systems

---

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review logs: `docker logs <container-name>`
3. Consult documentation:
   - DEPLOYMENT_GUIDE.md
   - Hyperledger Fabric docs: https://hyperledger-fabric.readthedocs.io/
4. Verify prerequisites are met
5. Ensure Docker group is active

---

## ⚡ Quick Command Reference

```bash
# Complete installation on fresh Kali
curl -sSL https://raw.githubusercontent.com/.../install-kali.sh | bash
newgrp docker                          # Activate docker group
cd ~/FYP-2
./scripts/deploy/complete-setup.sh     # Deploy blockchain

# Manual deployment
./scripts/deploy/setup-ca.sh
./scripts/deploy/generate-artifacts.sh
./scripts/deploy/start-hot-chain.sh
./scripts/deploy/create-channel-hot.sh
./scripts/deploy/deploy-chaincode.sh hot
./scripts/test/test-chaincode.sh hot

# Check status
docker ps                              # View containers
docker logs -f peer0.lab.hot.dfir.local  # View logs

# Stop everything
cd ~/FYP-2/fabric-network/hot-chain/docker
docker-compose -f docker-compose-orderers.yaml -f docker-compose-peers.yaml down
```

---

**Installation Guide Version:** 1.0
**Compatible with:** Kali Linux 2023.x+, Debian 11+
**Last Updated:** 2026-01-18
