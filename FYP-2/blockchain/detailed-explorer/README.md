# Detailed Blockchain Explorer

A comprehensive blockchain visualization tool for the DFIR Chain-of-Custody system. Unlike the basic management console, this explorer shows the actual blockchain structure including individual blocks, transactions, and their contents.

## Features

- **Dual-Chain Visualization**: Side-by-side view of Hot and Cold blockchains
- **Block-Level Details**: View individual blocks with their hashes, timestamps, and transaction counts
- **Transaction Inspection**: Drill down into transactions to see chaincode invocations, function calls, and arguments
- **Evidence Query**: Query evidence records directly and view their complete custody chain
- **Network Status**: Monitor running Fabric containers
- **Real-Time Updates**: Auto-refresh capability

## Quick Start

### Prerequisites

- Python 3.x
- Flask (`pip install flask flask-cors`)
- Running Fabric network (hot-chain and/or cold-chain)

### Start the Explorer

```bash
cd /home/kali/FYP-2/blockchain/detailed-explorer
./start-explorer.sh
```

Or manually:

```bash
python3 block-explorer-api.py
```

### Access the Explorer

Open in your browser: **http://localhost:3001**

## Architecture

```
Port 3001: Detailed Explorer API & UI
    |
    +-- /api/status         - Both chains status
    +-- /api/<chain>/info   - Chain info (height, hashes)
    +-- /api/<chain>/blocks - List blocks with pagination
    +-- /api/<chain>/block/<num> - Get specific block details
    +-- /api/<chain>/tx/<txid>   - Get transaction details
    +-- /api/<chain>/evidence    - Query evidence by ID
    +-- /api/<chain>/custody     - Get custody chain
    +-- /api/containers          - Check Docker containers
```

## Views

### 1. Overview
- Chain statistics (block height, transaction count, peer count)
- Visual block representation with clickable blocks
- Detailed block information when a block is selected
- Transaction list with expandable details

### 2. Block Explorer
- Full block listing for selected chain
- Block hashes and metadata
- Switch between hot and cold chains

### 3. Evidence Query
- Query evidence by Case ID and Evidence ID
- View complete evidence details (IPFS CID, hash, status)
- View custody chain timeline

### 4. Network Status
- List all running Fabric containers
- Health status indicators

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/status` | GET | Get status of both chains |
| `/api/<chain>/info` | GET | Get chain info (height, current hash, previous hash) |
| `/api/<chain>/blocks?start=0&limit=10` | GET | List blocks with pagination |
| `/api/<chain>/block/<num>` | GET | Get detailed block information |
| `/api/<chain>/tx/<txid>` | GET | Get transaction details by ID |
| `/api/<chain>/evidence?caseID=X&evidenceID=Y` | GET | Query evidence |
| `/api/<chain>/custody?caseID=X&evidenceID=Y` | GET | Get custody chain |
| `/api/containers` | GET | List running Fabric containers |

Where `<chain>` is either `hot` or `cold`.

## Comparison with Basic Explorer

| Feature | Basic Explorer (Port 5000) | Detailed Explorer (Port 3001) |
|---------|---------------------------|------------------------------|
| Block Count | Yes | Yes |
| Individual Blocks | No | Yes |
| Block Hashes | No | Yes |
| Transaction Details | No | Yes |
| Chaincode Actions | No | Yes |
| Visual Block Chain | No | Yes |
| Evidence Query | Yes | Yes |
| Custody Timeline | Yes | Yes (Enhanced) |

## Troubleshooting

### "Network Offline" Status

Ensure the Fabric network is running:

```bash
# Start hot chain
./scripts/deploy/start-hot-chain.sh

# Verify containers
docker ps | grep hot.dfir.local
```

### "API Unavailable"

Check if the API server is running:

```bash
curl http://localhost:3001/api/status
```

### Empty Block List

1. Check if the channel exists: `docker exec peer0.lab.hot.dfir.local peer channel list`
2. Check if chaincode is installed: `docker exec peer0.lab.hot.dfir.local peer lifecycle chaincode querycommitted -C evidence-hot`

## Technical Details

- **Port**: 3001 (configurable in block-explorer-api.py)
- **API Framework**: Flask with CORS support
- **Frontend**: Single-page HTML/CSS/JavaScript application
- **Block Decoding**: Uses Fabric peer CLI and configtxlator

## Files

```
detailed-explorer/
├── block-explorer-api.py   # Python API server
├── index.html              # Frontend UI
├── start-explorer.sh       # Startup script
└── README.md               # This file
```

## Security Note

This explorer is designed for development and demonstration purposes. For production use:

1. Add authentication
2. Use HTTPS
3. Restrict CORS origins
4. Add rate limiting
5. Run behind a reverse proxy
