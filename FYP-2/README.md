# Blockchain-based DFIR Chain-of-Custody System

A permissioned blockchain implementation for digital forensic evidence management using Hyperledger Fabric, Intel SGX, and IPFS.

## Overview

This Final Year Project implements a secure, legally-compliant chain-of-custody system for digital forensic evidence. The system addresses critical gaps in existing solutions through:

- **Dual-chain architecture**: Separate hot (active) and cold (archived) chains for scalability
- **Zero Trust gateway**: JumpServer as sole entry point with MFA and RBAC
- **TEE-based privacy**: Intel SGX enclaves for sensitive operations
- **Off-chain storage**: Private IPFS cluster for large evidence files
- **Legal compliance**: Designed for court admissibility under Lebanese Law No. 81/2018 and U.S. FRE 901/902

## Key Features

### Blockchain Layer (Hyperledger Fabric v3.0.0 LTS)
- Permissioned network with three organizations: ForensicLabMSP, CourtMSP, OrdererOrg
- RAFT consensus for deterministic finality
- CouchDB state database for rich JSON queries
- mTLS for all communications
- Dual channels: `evidence-hot` and `evidence-cold`

### Smart Contracts
**Public Chaincode** (custody operations):
- CreateEvidence
- TransferCustody
- ArchiveToCold / ReactivateFromCold
- InvalidateEvidence
- GetEvidenceSummary

**Private Chaincode** (SGX-based):
- Sensitive data processing in trusted execution environments
- Remote attestation protocol
- Casbin policy engine for authorization

### JumpServer Gateway
- Passwordless MFA (FIDO2/WebAuthn)
- Fabric Gateway SDK client
- Role-based access control (5 roles)
- Audit logging and session management

### IPFS Integration
- Private 4-node cluster (Lab, Court, Redundant, Replica)
- Content-addressed storage with CID references on-chain
- JumpServer-only access for Zero Trust compliance

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        JumpServer                           │
│              (MFA, RBAC, Audit Logging)                     │
└──────────┬───────────────────────────────────────┬──────────┘
           │                                       │
    ┌──────▼──────┐                        ┌──────▼──────┐
    │ Hot Chain   │                        │ Cold Chain  │
    │ (Active)    │◄──Archive/Reactivate──►│ (Archived)  │
    │             │                        │             │
    │ - RAFT      │                        │ - RAFT      │
    │ - CouchDB   │                        │ - CouchDB   │
    │ - SGX       │                        │ - Append-   │
    │   Enclaves  │                        │   Only      │
    └─────────────┘                        └─────────────┘
           │
           │ (CID references)
           │
    ┌──────▼──────────────────────────────┐
    │   Private IPFS Cluster              │
    │   (Off-chain Evidence Storage)      │
    └─────────────────────────────────────┘
```

## Project Structure

See [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) for detailed directory organization and component descriptions.

```
fabric-network/     # Hot and cold chain configurations
chaincode/          # Public and private smart contracts
jumpserver/         # Gateway client and RBAC policies
ipfs/               # Cluster configuration and scripts
scripts/            # Deployment and utility scripts
test/               # Unit, integration, and E2E tests
docs/               # Additional documentation
```

## Requirements

### Software
- Docker & Docker Compose
- Hyperledger Fabric v3.0.0 LTS binaries
- Go 1.21+ (for chaincode)
- Node.js 18+ (for JumpServer client)
- IPFS Kubo and IPFS Cluster
- Intel SGX SDK (for private chaincode)

### Hardware
- **Hot Chain**: 24 vCPUs, 48GB RAM, 3-4TB storage
- **Cold Chain**: 12 vCPUs, 24GB RAM, 3-4TB storage
- **IPFS**: 5-7TB total storage across nodes
- **Network**: 100 Mbps minimum, 1 Gbps recommended
- **SGX**: Intel CPUs with SGX support

## Standards Compliance

- ISO 23257:2022 (Blockchain and DLT)
- IEEE 2418.2-2020 (Blockchain for IoT)
- FIPS 180-4 (SHA-256/512)
- FIPS 186-5 (ECDSA signatures)
- TLS 1.3
- NIST SP 800-207 (Zero Trust)
- ISO/IEC 27037:2012 (Digital evidence)

## Getting Started

```bash
# 1. Clone the repository
git clone <repository-url>
cd FYP-2

# 2. Set up Fabric CA and generate crypto materials
./scripts/deploy/setup-ca.sh

# 3. Start the hot chain network
./scripts/deploy/start-hot-chain.sh

# 4. Deploy chaincode
./scripts/deploy/deploy-chaincode.sh

# 5. Start IPFS cluster
./scripts/deploy/start-ipfs.sh

# 6. Run JumpServer gateway
./scripts/deploy/start-jumpserver.sh

# 7. Run tests
./scripts/utils/run-tests.sh
```

## Evidence Lifecycle Flows

1. **Creation Flow**: Investigator → JumpServer → Public CC (CreateEvidence) → IPFS (store file) → Ledger (CID + metadata)

2. **Archive Flow**: LabAnalyst → JumpServer → Hot Chain (ArchiveToCold) → Cold Chain (create archived record)

3. **Verification Flow**: Auditor → JumpServer → Query ledger → Validate hash + custody chain

## Testing

```bash
# Unit tests
npm test --prefix test/unit

# Integration tests
npm test --prefix test/integration

# E2E tests
npm test --prefix test/e2e
```

## Documentation

- [FYP-Report.pdf](./FYP-Report.pdf) - Complete project report with architecture, methodology, and requirements
- [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) - Detailed directory structure and component descriptions
- [docs/](./docs/) - Additional technical documentation

## License

See [LICENSE](./LICENSE) for details.

## Author

American University of Beirut - Final Year Project

## Acknowledgments

- Hyperledger Fabric community
- Intel SGX documentation and SDK
- IPFS and Protocol Labs