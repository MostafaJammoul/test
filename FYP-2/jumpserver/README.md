# JumpServer - Zero Trust Gateway

The JumpServer is the sole entry point for all interactions with the DFIR blockchain system and IPFS cluster. It implements a Zero Trust architecture with comprehensive security controls.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Client Applications                │
└─────────────────────┬───────────────────────────────┘
                      │ HTTPS + WebAuthn MFA
                      ▼
┌─────────────────────────────────────────────────────┐
│                    JumpServer                        │
│  ┌──────────────────────────────────────────────┐   │
│  │  Authentication & Authorization Layer        │   │
│  │  - WebAuthn (FIDO2) MFA                      │   │
│  │  - JWT Token Management                      │   │
│  │  - RBAC Enforcement                          │   │
│  └──────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────┐   │
│  │  Fabric Gateway SDK Client                   │   │
│  │  - Hot Chain Connection                      │   │
│  │  - Cold Chain Connection                     │   │
│  │  - Transaction Management                    │   │
│  └──────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────┐   │
│  │  IPFS HTTP Client                            │   │
│  │  - Cluster API Integration                   │   │
│  │  - Content Management                        │   │
│  └──────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────┐   │
│  │  Audit & Logging                             │   │
│  │  - Winston Logger                            │   │
│  │  - Request/Response Logging                  │   │
│  │  - Security Event Tracking                   │   │
│  └──────────────────────────────────────────────┘   │
└────────┬─────────────────────────────┬──────────────┘
         │                             │
         ▼                             ▼
┌────────────────┐          ┌─────────────────────┐
│ Fabric Network │          │   IPFS Cluster      │
│  - Hot Chain   │          │  - Lab Node         │
│  - Cold Chain  │          │  - Court Node       │
└────────────────┘          │  - Redundant Node   │
                            │  - Replica Node     │
                            └─────────────────────┘
```

## Features

### Security

- **Zero Trust Architecture**: No implicit trust, every request authenticated and authorized
- **Passwordless MFA**: WebAuthn (FIDO2) for phishing-resistant authentication
- **Role-Based Access Control**: 5 distinct roles with granular permissions
- **TLS Everywhere**: All communications encrypted (client-to-gateway, gateway-to-fabric, gateway-to-ipfs)
- **Rate Limiting**: Prevents abuse and DoS attacks
- **Security Headers**: Helmet.js for comprehensive HTTP security headers
- **Audit Logging**: Complete audit trail of all operations

### Roles and Permissions

#### Investigator
- **Organization**: ForensicLabMSP
- **Permissions**:
  - Create new evidence records
  - Read evidence information
  - Transfer custody of evidence
  - Add files to IPFS
  - Retrieve files from IPFS

#### LabAnalyst
- **Organization**: ForensicLabMSP
- **Permissions**:
  - Read evidence information
  - Transfer custody of evidence
  - Archive evidence to cold chain
  - Reactivate archived evidence
  - Retrieve files from IPFS

#### CourtUser
- **Organization**: CourtMSP
- **Permissions**:
  - Read evidence information
  - Verify evidence integrity
  - Retrieve files from IPFS (read-only)

#### Auditor
- **Organization**: ForensicLabMSP or CourtMSP
- **Permissions**:
  - Read evidence information
  - Audit evidence and custody chains
  - Verify evidence integrity
  - Query custody chain history
  - Retrieve files from IPFS

#### Admin
- **Organization**: ForensicLabMSP or CourtMSP
- **Permissions**:
  - All evidence operations
  - All IPFS operations
  - Invalidate evidence
  - System management

### API Endpoints

#### Authentication

- `POST /api/auth/register`: Register new user with WebAuthn
- `POST /api/auth/login`: Authenticate with WebAuthn
- `POST /api/auth/refresh`: Refresh JWT token
- `POST /api/auth/logout`: Logout and invalidate token

#### Evidence Operations

- `POST /api/evidence/create`: Create new evidence record
  - Required: Investigator or Admin
  - Body: `{ caseId, evidenceId, file, metadata }`
  - Returns: Evidence object with CID and blockchain transaction ID

- `POST /api/evidence/transfer`: Transfer custody
  - Required: Investigator, LabAnalyst, or Admin
  - Body: `{ caseId, evidenceId, newCustodian, reason }`

- `POST /api/evidence/archive`: Archive to cold chain
  - Required: LabAnalyst or Admin
  - Body: `{ caseId, evidenceId, reason }`

- `POST /api/evidence/reactivate`: Reactivate from cold chain
  - Required: LabAnalyst or Admin
  - Body: `{ caseId, evidenceId, reason }`

- `POST /api/evidence/invalidate`: Invalidate evidence
  - Required: Admin only
  - Body: `{ caseId, evidenceId, reason, wrongTxId }`

- `GET /api/evidence/:caseId/:evidenceId`: Get evidence summary
  - Required: Any authenticated role
  - Returns: Complete evidence object

- `GET /api/evidence/:caseId/:evidenceId/custody`: Get custody chain
  - Required: Any authenticated role
  - Returns: Array of custody events

- `GET /api/evidence/case/:caseId`: Query evidence by case
  - Required: Any authenticated role
  - Returns: Array of evidence objects

- `GET /api/evidence/:caseId/:evidenceId/verify`: Verify evidence integrity
  - Required: CourtUser, Auditor, or Admin
  - Returns: Verification status (hash match, custody chain valid)

#### IPFS Operations

- `POST /api/ipfs/add`: Add file to IPFS cluster
  - Required: Investigator or Admin
  - Body: Multipart form data with file
  - Returns: CID and file hash

- `GET /api/ipfs/:cid`: Retrieve file from IPFS
  - Required: Any authenticated role
  - Returns: File stream

- `GET /api/ipfs/:cid/status`: Check replication status
  - Required: Auditor or Admin
  - Returns: Replication status across cluster nodes

## Configuration

### Environment Variables

Create a `.env` file in the `client` directory:

```env
# Server Configuration
NODE_ENV=production
PORT=3000
ALLOWED_ORIGINS=https://dfir-app.example.com

# Fabric Hot Chain Configuration
HOT_PEER_ENDPOINT=peer0.lab.hot.dfir.local:7051
HOT_PEER_HOST_ALIAS=peer0.lab.hot.dfir.local
HOT_CHANNEL_NAME=evidence-hot
HOT_CRYPTO_PATH=/path/to/hot-chain/crypto-config
HOT_CERT_PATH=/path/to/user/cert.pem
HOT_KEY_PATH=/path/to/user/key.pem
HOT_TLS_CERT_PATH=/path/to/peer/tls/ca.crt

# Fabric Cold Chain Configuration
COLD_PEER_ENDPOINT=peer0.lab.cold.dfir.local:9051
COLD_PEER_HOST_ALIAS=peer0.lab.cold.dfir.local
COLD_CHANNEL_NAME=evidence-cold
COLD_CRYPTO_PATH=/path/to/cold-chain/crypto-config
COLD_CERT_PATH=/path/to/user/cert.pem
COLD_KEY_PATH=/path/to/user/key.pem
COLD_TLS_CERT_PATH=/path/to/peer/tls/ca.crt

# MSP Configuration
MSP_ID=ForensicLabMSP

# IPFS Configuration
IPFS_API_URL=http://ipfs-cluster-lab:9094
IPFS_REPLICATION_FACTOR=3

# JWT Configuration
JWT_SECRET=your-secret-key-change-this
JWT_EXPIRES_IN=1h
JWT_REFRESH_EXPIRES_IN=7d

# WebAuthn Configuration
WEBAUTHN_RP_NAME=DFIR Blockchain System
WEBAUTHN_RP_ID=dfir.example.com
WEBAUTHN_ORIGIN=https://dfir.example.com

# Logging
LOG_LEVEL=info
```

### RBAC Configuration

Role permissions are defined in `rbac/roles.json`. To modify:

1. Edit the roles.json file
2. Add/remove permissions as needed
3. Restart the JumpServer

## Installation

```bash
# Install dependencies
cd jumpserver/client
npm install

# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Start in development mode
npm run dev

# Start in production mode
npm start
```

## Usage Examples

### Create Evidence

```bash
curl -X POST https://jumpserver:3000/api/evidence/create \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "caseId=CASE001" \
  -F "evidenceId=EVD001" \
  -F "file=@/path/to/evidence.img" \
  -F "metadata={\"type\":\"disk-image\",\"size\":104857600}"
```

### Transfer Custody

```bash
curl -X POST https://jumpserver:3000/api/evidence/transfer \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "caseId": "CASE001",
    "evidenceId": "EVD001",
    "newCustodian": "analyst-john",
    "reason": "Transferred for analysis"
  }'
```

### Verify Evidence

```bash
curl -X GET https://jumpserver:3000/api/evidence/CASE001/EVD001/verify \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Security Considerations

### Production Deployment

1. **TLS Configuration**:
   - Use valid TLS certificates from trusted CA
   - Enable HSTS with long max-age
   - Configure TLS 1.3 minimum

2. **Firewall Rules**:
   - Restrict JumpServer access to authorized IP ranges
   - Block direct access to Fabric peers and IPFS nodes
   - Only allow JumpServer to communicate with backend systems

3. **Key Management**:
   - Use HSM for private key storage in production
   - Rotate JWT secrets regularly
   - Implement key escrow for disaster recovery

4. **Rate Limiting**:
   - Adjust rate limits based on expected traffic
   - Implement per-user rate limiting
   - Consider DDoS protection service

5. **Monitoring**:
   - Set up alerts for failed authentication attempts
   - Monitor audit logs for suspicious activity
   - Track blockchain transaction failures

### WebAuthn Security

- Use attestation to verify authenticator legitimacy
- Require user verification (PIN/biometric) for sensitive operations
- Support multiple authenticators per user for redundancy
- Store credential IDs securely (encrypted in database)

## Monitoring and Logging

### Log Files

- `logs/error.log`: Error-level logs
- `logs/combined.log`: All logs
- `logs/audit.log`: Audit trail of all operations

### Log Format

```json
{
  "timestamp": "2026-01-18T12:00:00.000Z",
  "level": "info",
  "message": "Evidence created",
  "userId": "user123",
  "role": "Investigator",
  "caseId": "CASE001",
  "evidenceId": "EVD001",
  "txId": "a1b2c3d4e5f6...",
  "service": "jumpserver-gateway"
}
```

### Metrics to Monitor

- Authentication success/failure rates
- API endpoint latency
- Fabric transaction success rates
- IPFS upload/download speeds
- Active user sessions
- Rate limit violations

## Troubleshooting

### Connection to Fabric Failed

1. Verify peer endpoints are reachable
2. Check TLS certificates are valid
3. Ensure crypto materials are correctly configured
4. Verify MSP ID matches the peer organization

### WebAuthn Registration Fails

1. Check RP ID matches domain
2. Verify HTTPS is enabled
3. Ensure origin matches configuration
4. Check browser WebAuthn support

### IPFS Upload Fails

1. Verify IPFS cluster is running
2. Check cluster API endpoint
3. Ensure sufficient storage space
4. Verify network connectivity to cluster

## Development

### Running Tests

```bash
npm test
```

### Code Linting

```bash
npm run lint
```

### Development Mode

```bash
npm run dev  # Auto-reloads on file changes
```

## License

See project LICENSE file.
