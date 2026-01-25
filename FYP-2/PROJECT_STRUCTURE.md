# Project Structure

This document describes the organization of the Blockchain-based DFIR Chain-of-Custody system.

## Directory Overview

```
FYP-2/
├── fabric-network/           # Hyperledger Fabric blockchain networks
│   ├── hot-chain/           # Active investigation chain
│   │   ├── config/          # Network configuration files (configtx.yaml, core.yaml)
│   │   ├── crypto-config/   # PKI materials (CAs, MSPs, certificates)
│   │   ├── channel-artifacts/ # Channel creation and update transactions
│   │   └── docker/          # Docker Compose orchestration for hot chain
│   └── cold-chain/          # Archived evidence chain
│       ├── config/          # Network configuration files
│       ├── crypto-config/   # PKI materials for cold chain
│       ├── channel-artifacts/ # Channel artifacts for cold chain
│       └── docker/          # Docker Compose orchestration for cold chain
│
├── chaincode/               # Smart contract implementations
│   ├── public/              # Public chaincode (custody operations)
│   │                        # Functions: CreateEvidence, TransferCustody,
│   │                        # ArchiveToCold, ReactivateFromCold, etc.
│   └── private-sgx/         # Intel SGX-based private chaincode
│                            # Handles sensitive operations with TEE
│
├── jumpserver/              # Gateway and access control
│   ├── client/              # Fabric Gateway client implementation
│   │                        # Sole entry point for blockchain interaction
│   ├── config/              # JumpServer configuration
│   │                        # MFA, connection pooling, session management
│   └── rbac/                # Role-based access control policies
│                            # Roles: Investigator, LabAnalyst, CourtUser, Auditor, Admin
│
├── ipfs/                    # Off-chain storage system
│   ├── cluster-config/      # Private IPFS cluster configuration
│   │                        # 4-node cluster: Lab, Court, Redundant, Replica
│   └── scripts/             # IPFS management and integration scripts
│
├── scripts/                 # Automation and utilities
│   ├── deploy/              # Deployment automation scripts
│   │                        # Network bootstrap, chaincode deployment, etc.
│   └── utils/               # Utility scripts for management and maintenance
│
├── test/                    # Testing infrastructure
│   ├── unit/                # Unit tests for chaincode and components
│   ├── integration/         # Integration tests for component interactions
│   └── e2e/                 # End-to-end workflow tests
│                            # Evidence lifecycle, custody chain, archival flows
│
└── docs/                    # Additional documentation
                             # Architecture diagrams, deployment guides, API docs
```

## Component Details

### Fabric Network

The system implements a **dual-chain architecture**:

- **Hot Chain**: Handles active investigations with full CRUD operations
  - Organizations: ForensicLabMSP, CourtMSP, OrdererOrg
  - Consensus: RAFT (3-node minimum)
  - State DB: CouchDB for rich queries
  - Channel: `evidence-hot`

- **Cold Chain**: Stores archived cases (append-only)
  - Same organizational structure
  - Separate RAFT cluster
  - Channel: `evidence-cold`

### Chaincode Architecture

#### Public Chaincode
Located in `chaincode/public/`, implements:
- `CreateEvidence(caseID, evidenceID, cid, hash, metadata)`
- `TransferCustody(evidenceID, newCustodian)`
- `ArchiveToCold(caseID, evidenceID)`
- `ReactivateFromCold(evidenceID)`
- `InvalidateEvidence(evidenceID, reason, wrongTxID)`
- `GetEvidenceSummary(evidenceID)`

World state key design: `caseID:evidenceID`

#### Private SGX Chaincode
Located in `chaincode/private-sgx/`, provides:
- Trusted Execution Environment (TEE) for sensitive operations
- Remote attestation for enclave verification
- Casbin-based authorization policies
- Memory-constrained operations (<100MB SGX limit)

### JumpServer Gateway

Zero Trust architecture component:
- **Sole gateway** for all blockchain interactions
- Passwordless MFA (FIDO2/WebAuthn)
- Client certificate authentication
- Role-based access control enforcement
- Audit logging for all operations

### IPFS Cluster

Private content-addressed storage:
- 4-node cluster configuration
- JumpServer-only access (no direct client access)
- Content Identifier (CID) based addressing
- Redundancy and replication
- Integration with chaincode (CID references on-chain)

### Testing Strategy

- **Unit Tests**: Individual chaincode function validation
- **Integration Tests**: Component interaction verification
  - Fabric-IPFS integration
  - JumpServer-Fabric Gateway communication
  - SGX attestation workflows
- **E2E Tests**: Complete evidence lifecycle scenarios
  - Create → Transfer → Archive flow
  - Reactivation workflow
  - Invalidation and tamper detection
  - Multi-org endorsement validation

## Standards Compliance

- **ISO 23257:2022**: Blockchain and distributed ledger technologies
- **IEEE 2418.2-2020**: Blockchain for IoT data management
- **FIPS 180-4**: SHA-256/512 hashing
- **FIPS 186-5**: Digital signatures (ECDSA)
- **TLS 1.3**: All network communications
- **NIST SP 800-207**: Zero Trust Architecture
- **ISO/IEC 27037:2012**: Digital evidence collection and preservation

## Legal Compliance

- Lebanese Law No. 81/2018
- U.S. Federal Rules of Evidence (FRE 901, 902)
- Council of Europe Guidelines on Electronic Evidence

## Development Workflow

1. **Setup**: Configure Fabric CAs and generate crypto materials
2. **Network Bootstrap**: Start orderers and peers for both chains
3. **Channel Creation**: Create and join `evidence-hot` and `evidence-cold` channels
4. **Chaincode Deployment**: Package, install, approve, and commit chaincode
5. **IPFS Cluster**: Deploy and configure private IPFS nodes
6. **JumpServer**: Deploy gateway with Fabric SDK and RBAC policies
7. **SGX Integration**: Deploy private chaincode with remote attestation
8. **Testing**: Run comprehensive test suite
9. **Monitoring**: Set up logging and metrics collection

## Resource Requirements

### Hot Chain
- Compute: 24 vCPUs, 48GB RAM
- Storage: 3-4TB (5-year horizon)
- Network: 100 Mbps minimum, 1 Gbps recommended

### Cold Chain
- Compute: 12 vCPUs, 24GB RAM
- Storage: 3-4TB (append-only archive)
- Network: 100 Mbps minimum

### IPFS Cluster
- Storage: 5-7TB total across 4 nodes
- Network: 1 Gbps for large evidence files

## Next Steps

Refer to deployment scripts in `scripts/deploy/` for automated setup procedures.
