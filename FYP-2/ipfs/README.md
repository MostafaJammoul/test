# Private IPFS Cluster for DFIR Evidence Storage

This directory contains the configuration and scripts for deploying a private IPFS cluster for off-chain evidence storage.

## Architecture

The cluster consists of 4 nodes:

1. **Lab Node**: Primary storage for ForensicLabMSP
2. **Court Node**: Primary storage for CourtMSP
3. **Redundant Node**: Backup storage for high availability
4. **Replica Node**: Additional replication for data durability

All nodes are configured as a **private IPFS network** isolated from the public IPFS network. Only nodes with the correct swarm key can join the cluster.

## Security Features

- **Private Network**: Swarm key required for node participation
- **No Public Gateway**: Nodes do not expose public gateways
- **JumpServer-Only Access**: In production, only JumpServer can interact with the cluster
- **Content Addressing**: Immutable CID-based addressing ensures data integrity
- **Replication**: Multi-node replication prevents data loss

## Directory Structure

```
ipfs/
├── cluster-config/           # Docker Compose and cluster configuration
│   ├── docker-compose-ipfs.yaml
│   ├── swarm.key            # Generated private network key (not in git)
│   └── .env                 # Environment variables (not in git)
├── scripts/                 # Management scripts
│   ├── generate-swarm-key.sh
│   ├── start-ipfs-cluster.sh
│   ├── ipfs-init-lab.sh
│   ├── ipfs-init-court.sh
│   ├── ipfs-init-redundant.sh
│   └── ipfs-init-replica.sh
└── README.md
```

## Quick Start

### 1. Generate Swarm Key

First, generate a private swarm key for the cluster:

```bash
cd ipfs/scripts
./generate-swarm-key.sh
```

This creates:
- `cluster-config/swarm.key`: Private network swarm key
- `cluster-config/.env`: Environment variables including cluster secret

**IMPORTANT**: These files contain secrets and should NOT be committed to version control. They are already in `.gitignore`.

### 2. Start the Cluster

```bash
cd ipfs/scripts
./start-ipfs-cluster.sh
```

This will:
- Start all 4 IPFS nodes
- Start all 4 IPFS Cluster peers
- Wait for initialization
- Display cluster status and endpoints

### 3. Verify Cluster Status

Check that all nodes are connected:

```bash
# List cluster peers
docker exec ipfs-cluster-lab ipfs-cluster-ctl peers ls

# Check node health
docker exec ipfs-cluster-lab ipfs-cluster-ctl health graph
```

## Node Endpoints

### IPFS API Endpoints
- **Lab**: http://localhost:5001
- **Court**: http://localhost:5011
- **Redundant**: http://localhost:5021
- **Replica**: http://localhost:5031

### IPFS Gateway Endpoints
- **Lab**: http://localhost:8080
- **Court**: http://localhost:8081
- **Redundant**: http://localhost:8082
- **Replica**: http://localhost:8083

### Cluster API Endpoints
- **Lab**: http://localhost:9094
- **Court**: http://localhost:9096
- **Redundant**: http://localhost:9098
- **Replica**: http://localhost:9100

## Usage Examples

### Add Evidence File to Cluster

```bash
# Add file via cluster (automatically replicates across nodes)
docker exec ipfs-cluster-lab ipfs-cluster-ctl add /path/to/evidence.img

# Returns CID (Content Identifier)
# Example: QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG
```

### Retrieve Evidence File

```bash
# Get file using CID
docker exec ipfs-lab ipfs cat QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG > retrieved.img

# Verify hash matches blockchain record
sha256sum retrieved.img
```

### Check Replication Status

```bash
# Check which nodes have a specific CID
docker exec ipfs-cluster-lab ipfs-cluster-ctl status QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG
```

### Pin Management

```bash
# List all pins
docker exec ipfs-cluster-lab ipfs-cluster-ctl pin ls

# Pin specific CID
docker exec ipfs-cluster-lab ipfs-cluster-ctl pin add QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG

# Unpin CID
docker exec ipfs-cluster-lab ipfs-cluster-ctl pin rm QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG
```

## Integration with Blockchain

The IPFS cluster integrates with the Fabric chaincode as follows:

1. **Evidence Creation Flow**:
   ```
   User → JumpServer → IPFS Cluster (add file) → Get CID
                    ↓
                 Compute SHA-256 hash
                    ↓
                 Blockchain (store CID + hash)
   ```

2. **Evidence Verification Flow**:
   ```
   User → JumpServer → Blockchain (get CID + hash)
                    ↓
                 IPFS Cluster (retrieve file via CID)
                    ↓
                 Compute SHA-256 hash
                    ↓
                 Compare hashes (integrity verification)
   ```

3. **Chaincode Integration**:
   - CID is stored on-chain in `Evidence.CID` field
   - File hash is stored on-chain in `Evidence.Hash` field
   - JumpServer acts as the sole bridge between blockchain and IPFS

## Cluster Configuration

### Replication Factor

By default, the cluster replicates content across all 4 nodes. You can adjust replication settings:

```bash
# Set replication factor to 3
docker exec ipfs-cluster-lab ipfs-cluster-ctl pin add \
  --replication-min 3 \
  --replication-max 3 \
  QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG
```

### Storage Limits

Each node is configured with a 2TB storage limit. Adjust in initialization scripts if needed:

```bash
ipfs config Datastore.StorageMax "2TB"
```

## Monitoring and Maintenance

### Check Cluster Health

```bash
# Overall cluster health
docker exec ipfs-cluster-lab ipfs-cluster-ctl health metrics

# Node-specific health
docker logs ipfs-cluster-lab
```

### Garbage Collection

IPFS automatically garbage collects unpinned content when storage is low:

```bash
# Manual garbage collection
docker exec ipfs-lab ipfs repo gc
```

### Backup and Recovery

The cluster provides built-in redundancy. For additional backup:

```bash
# Export cluster state
docker exec ipfs-cluster-lab ipfs-cluster-ctl state export > cluster-state-backup.json

# Import cluster state (disaster recovery)
docker exec ipfs-cluster-lab ipfs-cluster-ctl state import cluster-state-backup.json
```

## Stopping the Cluster

```bash
cd ipfs/cluster-config
docker-compose -f docker-compose-ipfs.yaml down

# To also remove volumes (WARNING: deletes all data)
docker-compose -f docker-compose-ipfs.yaml down -v
```

## Security Considerations

1. **Private Network**: The swarm key ensures only authorized nodes can join
2. **API Access Control**: In production, configure firewall rules to restrict API access to JumpServer only
3. **TLS**: For production, enable TLS on cluster APIs
4. **Encryption at Rest**: Consider encrypting Docker volumes
5. **Audit Logging**: Monitor API access and file operations

## Resource Requirements

Per node:
- **CPU**: 2 vCPUs
- **RAM**: 4 GB
- **Storage**: 2 TB
- **Network**: 1 Gbps for large evidence files

Total cluster:
- **CPU**: 8 vCPUs
- **RAM**: 16 GB
- **Storage**: 8 TB (with 4x replication)

## Troubleshooting

### Nodes Not Connecting

1. Check swarm key is identical on all nodes
2. Verify network connectivity between containers
3. Check Docker logs: `docker logs ipfs-lab`

### Cluster Peers Not Finding Each Other

1. Wait 1-2 minutes for peer discovery
2. Manually connect peers:
   ```bash
   docker exec ipfs-cluster-lab ipfs-cluster-ctl peers add <peer-multiaddress>
   ```

### Out of Storage

1. Check storage usage: `docker exec ipfs-lab ipfs repo stat`
2. Run garbage collection: `docker exec ipfs-lab ipfs repo gc`
3. Increase storage limit in init scripts

### CID Not Found

1. Check if CID is pinned: `docker exec ipfs-cluster-lab ipfs-cluster-ctl pin ls | grep <CID>`
2. Check replication status: `docker exec ipfs-cluster-lab ipfs-cluster-ctl status <CID>`
3. Re-pin if needed: `docker exec ipfs-cluster-lab ipfs-cluster-ctl pin add <CID>`

## Performance Tuning

For better performance with large forensic images:

```bash
# Increase chunk size for large files
ipfs config --json Datastore.BloomFilterSize 1048576

# Adjust connection limits
ipfs config --json Swarm.ConnMgr.HighWater 100
ipfs config --json Swarm.ConnMgr.LowWater 50

# Enable filestore for large files (avoids copying)
ipfs config --json Experimental.FilestoreEnabled true
```

## License

See project LICENSE file.
