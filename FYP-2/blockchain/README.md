# Chain of Custody - Dual Blockchain System

## Digital Forensics Evidence Management System
### American University of Beirut - Final Year Project

---

## Overview

This system implements a dual-chain Hyperledger Fabric blockchain architecture for managing digital forensics chain of custody. It features:

- **Hot Chain**: For active, ongoing cases requiring frequent access
- **Cold Chain**: For archived cases and long-term evidence storage
- **8 Core Chaincode Functions**: Complete evidence lifecycle management
- **Web-based Management GUI**: Easy-to-use interface for all operations
- **Hyperledger Explorer**: Visual blockchain monitoring

---

## Quick Start

### Starting the System

```bash
cd /home/kali/FYP-2/blockchain
./start-all.sh
```

### Stopping the System

```bash
cd /home/kali/FYP-2/blockchain
./stop-all.sh
```

---

## Access Points

| Service | URL | Description |
|---------|-----|-------------|
| **Management GUI** | http://localhost:8083 | Main interface for all blockchain operations |
| **API Server** | http://localhost:5000 | REST API for programmatic access |
| **Hot Chain Explorer** | http://localhost:8081 | Hyperledger Explorer for hot chain |
| **Cold Chain Explorer** | http://localhost:8082 | Hyperledger Explorer for cold chain |

---

## Hyperledger Explorer Credentials

```
Username: exploreradmin
Password: exploreradminpw
```

---

## Architecture

### Network Configuration

#### Hot Chain
| Component | Container | Port |
|-----------|-----------|------|
| Orderer 1 | orderer.hot.coc.com | 7050 |
| Orderer 2 | orderer2.hot.coc.com | 7055 |
| Orderer 3 | orderer3.hot.coc.com | 7057 |
| ForensicLab Peer | peer0.forensiclab.hot.coc.com | 8051 |
| Court Peer | peer0.court.hot.coc.com | 7051 |
| Chaincode | coc-chaincode-hot | 9999 |

#### Cold Chain
| Component | Container | Port |
|-----------|-----------|------|
| Orderer 1 | orderer.cold.coc.com | 8050 |
| Orderer 2 | orderer2.cold.coc.com | 8055 |
| Orderer 3 | orderer3.cold.coc.com | 8057 |
| ForensicLab Peer | peer0.forensiclab.cold.coc.com | 10051 |
| Court Peer | peer0.court.cold.coc.com | 9051 |
| Chaincode | coc-chaincode-cold | 9998 |

### Organizations

- **ForensicLabMSP**: Forensic laboratory organization
- **CourtMSP**: Court/legal organization
- **OrdererMSP**: Orderer organization

---

## Chaincode Functions

| # | Function | Description |
|---|----------|-------------|
| 1 | CreateEvidence | Create new evidence record |
| 2 | TransferCustody | Transfer to new custodian |
| 3 | ArchiveToCold | Mark as archived |
| 4 | ReactivateFromCold | Reactivate archived evidence |
| 5 | InvalidateEvidence | Mark as invalid |
| 6 | GetEvidenceSummary | Get evidence summary |
| 7 | QueryEvidencesByCase | Query all evidence for case |
| 8 | GetCustodyChain | Get custody history |

---

## Evidence Types Supported

- Disk Images (E01, DD)
- Memory Dumps
- Network Captures (PCAP)
- Mobile Device Extractions
- Documents/Files
- Log Files

---

## Directory Structure

```
/home/kali/FYP-2/blockchain/
├── start-all.sh              # Start all services
├── stop-all.sh               # Stop all services
├── README.md                 # This file
├── hot-chain/                # Hot chain config
├── cold-chain/               # Cold chain config
├── chaincode/coc/            # Smart contract code
├── explorer/                 # GUI and monitoring
│   ├── api-server.py         # REST API
│   └── gui/index.html        # Web interface
└── scripts/                  # Utility scripts
```

---

## Troubleshooting

### Check container status
```bash
docker ps | grep -E "(hot|cold|coc|explorer)"
```

### View logs
```bash
docker logs <container_name>
```

### Reset system
```bash
./stop-all.sh
docker system prune -f
./start-all.sh
```

---

## Security

- TLS encryption on all communications
- mTLS for peer authentication
- Isolated chaincode containers
- Protected CouchDB databases

---

*American University of Beirut - Final Year Project*
