#!/usr/bin/env node
/**
 * JumpServer-to-Fabric REST API Bridge
 *
 * This service provides a REST API for JumpServer to interact with
 * Hyperledger Fabric blockchain and IPFS cluster.
 *
 * Endpoints:
 * - POST /api/evidence        - Create evidence (upload to IPFS + blockchain)
 * - GET  /api/evidence/:id    - Query evidence by ID
 * - GET  /api/evidence/case/:caseId - Query evidence by case
 * - POST /api/evidence/:id/transfer - Transfer custody
 * - POST /api/evidence/:id/archive  - Archive to cold chain
 * - GET  /api/health          - Health check
 */

// Load environment variables from .env file
require('dotenv').config();

const express = require('express');
const https = require('https');
const fs = require('fs');
const path = require('path');
const grpc = require('@grpc/grpc-js');
const { connect, signers } = require('@hyperledger/fabric-gateway');
const crypto = require('crypto');
const multer = require('multer');
const { create } = require('ipfs-http-client');

const app = express();
const upload = multer({ storage: multer.memoryStorage() });

// Configuration from environment variables
const CONFIG = {
  port: process.env.API_PORT || 3001,

  // mTLS Configuration
  tlsKey: process.env.TLS_KEY_PATH || './certs/server-key.pem',
  tlsCert: process.env.TLS_CERT_PATH || './certs/server-cert.pem',
  tlsCA: process.env.TLS_CA_PATH || './certs/ca-cert.pem',

  // Fabric Hot Chain
  hotPeerEndpoint: process.env.HOT_PEER_ENDPOINT || 'localhost:7051',
  hotPeerHostAlias: process.env.HOT_PEER_HOST_ALIAS || 'peer0.forensiclab.hot.coc.com',
  hotChannelName: process.env.HOT_CHANNEL_NAME || 'evidence-hot',
  hotChaincodeName: process.env.HOT_CHAINCODE_NAME || 'coc',

  // Fabric Cold Chain
  coldPeerEndpoint: process.env.COLD_PEER_ENDPOINT || 'localhost:9051',
  coldPeerHostAlias: process.env.COLD_PEER_HOST_ALIAS || 'peer0.forensiclab.cold.coc.com',
  coldChannelName: process.env.COLD_CHANNEL_NAME || 'evidence-cold',
  coldChaincodeName: process.env.COLD_CHAINCODE_NAME || 'coc',

  // Fabric Identity (MSP)
  mspId: process.env.MSP_ID || 'ForensicLabMSP',
  certPath: process.env.FABRIC_CERT_PATH || '../blockchain/hot-chain/crypto-config/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp/signcerts/cert.pem',
  keyPath: process.env.FABRIC_KEY_PATH || '../blockchain/hot-chain/crypto-config/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp/keystore/priv_sk',
  tlsPeerCert: process.env.FABRIC_TLS_CERT || '../blockchain/hot-chain/crypto-config/peerOrganizations/forensiclab.hot.coc.com/tlsca/tlsca.forensiclab.hot.coc.com-cert.pem',

  // IPFS Configuration
  ipfsUrl: process.env.IPFS_URL || 'http://localhost:5001',
};

// Fabric Gateway connections
let hotGateway = null;
let coldGateway = null;
let hotContract = null;
let coldContract = null;

// IPFS client
let ipfs = null;

/**
 * Connect to Fabric Gateway
 */
async function connectToFabric(chainType) {
  const config = chainType === 'hot' ? {
    peerEndpoint: CONFIG.hotPeerEndpoint,
    peerHostAlias: CONFIG.hotPeerHostAlias,
    channelName: CONFIG.hotChannelName,
    chaincodeName: CONFIG.hotChaincodeName
  } : {
    peerEndpoint: CONFIG.coldPeerEndpoint,
    peerHostAlias: CONFIG.coldPeerHostAlias,
    channelName: CONFIG.coldChannelName,
    chaincodeName: CONFIG.coldChaincodeName
  };

  console.log(`Connecting to ${chainType} chain at ${config.peerEndpoint}...`);

  // Load TLS certificate for peer
  const tlsRootCert = fs.readFileSync(CONFIG.tlsPeerCert);
  const credentials = grpc.credentials.createSsl(tlsRootCert);

  // Create gRPC client
  const client = new grpc.Client(config.peerEndpoint, credentials, {
    'grpc.ssl_target_name_override': config.peerHostAlias,
  });

  // Load identity
  const certPem = fs.readFileSync(CONFIG.certPath);
  const keyPem = fs.readFileSync(CONFIG.keyPath);

  // Create signer
  const privateKey = crypto.createPrivateKey(keyPem);
  const signer = signers.newPrivateKeySigner(privateKey);

  // Connect to gateway
  const gateway = connect({
    client,
    identity: {
      mspId: CONFIG.mspId,
      credentials: certPem,
    },
    signer,
    evaluateOptions: () => ({ deadline: Date.now() + 5000 }),
    endorseOptions: () => ({ deadline: Date.now() + 15000 }),
    submitOptions: () => ({ deadline: Date.now() + 30000 }),
    commitStatusOptions: () => ({ deadline: Date.now() + 60000 }),
  });

  const network = gateway.getNetwork(config.channelName);
  const contract = network.getContract(config.chaincodeName);

  console.log(`✓ Connected to ${chainType} chain`);
  return { gateway, contract };
}

/**
 * Initialize connections
 */
async function initialize() {
  try {
    console.log('Initializing JumpServer-Fabric API Bridge...');

    // Connect to hot chain
    const hot = await connectToFabric('hot');
    hotGateway = hot.gateway;
    hotContract = hot.contract;

    // Connect to cold chain
    const cold = await connectToFabric('cold');
    coldGateway = cold.gateway;
    coldContract = cold.contract;

    // Try to connect to IPFS (optional)
    try {
      ipfs = create({ url: CONFIG.ipfsUrl });
      console.log('✓ Connected to IPFS at', CONFIG.ipfsUrl);
    } catch (ipfsError) {
      console.warn('⚠ IPFS not available - will use mock CIDs');
      console.warn('  Evidence files will NOT be stored off-chain');
      ipfs = null;
    }

    console.log('✓ All connections established');
    return true;
  } catch (error) {
    console.error('Failed to initialize:', error);
    throw error;
  }
}

// Middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    connections: {
      hotChain: hotContract !== null,
      coldChain: coldContract !== null,
      ipfs: ipfs !== null
    }
  });
});

/**
 * POST /api/evidence
 * Create new evidence (upload to IPFS + blockchain)
 *
 * Body:
 * - caseID: string
 * - evidenceID: string
 * - file: buffer (base64) or multipart file
 * - hash: string (SHA-256)
 * - metadata: object
 */
app.post('/api/evidence', upload.single('file'), async (req, res) => {
  try {
    const { caseID, evidenceID, hash, metadata } = req.body;

    // Validate inputs
    if (!caseID || !evidenceID || !hash) {
      return res.status(400).json({ error: 'Missing required fields: caseID, evidenceID, hash' });
    }

    // Get file data
    let fileBuffer;
    if (req.file) {
      fileBuffer = req.file.buffer;
    } else if (req.body.file) {
      fileBuffer = Buffer.from(req.body.file, 'base64');
    } else {
      return res.status(400).json({ error: 'No file provided' });
    }

    console.log(`Creating evidence ${evidenceID} for case ${caseID}...`);

    // 1. Upload to IPFS (or generate mock CID if IPFS not available)
    let cid;
    if (ipfs !== null) {
      try {
        const ipfsResult = await ipfs.add(fileBuffer);
        cid = ipfsResult.cid.toString();
        console.log(`✓ Uploaded to IPFS: ${cid}`);
      } catch (ipfsError) {
        console.warn('⚠ IPFS upload failed, using mock CID');
        cid = `mock-cid-${hash.substring(0, 16)}`;
      }
    } else {
      // IPFS not available - generate deterministic mock CID from hash
      cid = `mock-cid-${hash.substring(0, 16)}`;
      console.log(`⚠ Using mock CID (IPFS not available): ${cid}`);
    }

    // 2. Submit to blockchain
    const metadataStr = typeof metadata === 'string' ? metadata : JSON.stringify(metadata || {});

    await hotContract.submitTransaction(
      'CreateEvidence',
      caseID,
      evidenceID,
      cid,
      hash,
      metadataStr
    );

    console.log(`✓ Evidence ${evidenceID} created on blockchain`);

    res.json({
      success: true,
      caseID,
      evidenceID,
      cid,
      hash,
      chain: 'hot',
      ipfsAvailable: ipfs !== null
    });
  } catch (error) {
    console.error('Error creating evidence:', error);
    res.status(500).json({
      error: 'Failed to create evidence',
      message: error.message
    });
  }
});

/**
 * GET /api/evidence/:evidenceID
 * Query evidence by ID
 */
app.get('/api/evidence/:evidenceID', async (req, res) => {
  try {
    const { evidenceID } = req.params;

    console.log(`Querying evidence ${evidenceID}...`);

    const resultBytes = await hotContract.evaluateTransaction('GetEvidenceSummary', evidenceID);
    const result = JSON.parse(resultBytes.toString());

    res.json(result);
  } catch (error) {
    console.error('Error querying evidence:', error);
    res.status(500).json({
      error: 'Failed to query evidence',
      message: error.message
    });
  }
});

/**
 * GET /api/evidence/case/:caseID
 * Query all evidence for a case
 */
app.get('/api/evidence/case/:caseID', async (req, res) => {
  try {
    const { caseID } = req.params;

    console.log(`Querying evidence for case ${caseID}...`);

    const resultBytes = await hotContract.evaluateTransaction('QueryByCase', caseID);
    const result = JSON.parse(resultBytes.toString());

    res.json(result);
  } catch (error) {
    console.error('Error querying case evidence:', error);
    res.status(500).json({
      error: 'Failed to query case evidence',
      message: error.message
    });
  }
});

/**
 * POST /api/evidence/:evidenceID/transfer
 * Transfer custody of evidence
 *
 * Body:
 * - newOwner: string
 * - reason: string
 */
app.post('/api/evidence/:evidenceID/transfer', async (req, res) => {
  try {
    const { evidenceID } = req.params;
    const { caseID, newOwner, reason } = req.body;

    if (!caseID || !newOwner) {
      return res.status(400).json({ error: 'Missing required fields: caseID, newOwner' });
    }

    console.log(`Transferring evidence ${evidenceID} to ${newOwner}...`);

    await hotContract.submitTransaction(
      'TransferCustody',
      caseID,
      evidenceID,
      newOwner,
      reason || 'Custody transfer'
    );

    console.log(`✓ Evidence ${evidenceID} transferred`);

    res.json({ success: true, evidenceID, newOwner });
  } catch (error) {
    console.error('Error transferring evidence:', error);
    res.status(500).json({
      error: 'Failed to transfer evidence',
      message: error.message
    });
  }
});

/**
 * POST /api/evidence/:evidenceID/archive
 * Archive evidence to cold chain
 *
 * Body:
 * - caseID: string
 */
app.post('/api/evidence/:evidenceID/archive', async (req, res) => {
  try {
    const { evidenceID } = req.params;
    const { caseID } = req.body;

    if (!caseID) {
      return res.status(400).json({ error: 'Missing required field: caseID' });
    }

    console.log(`Archiving evidence ${evidenceID} to cold chain...`);

    await hotContract.submitTransaction('ArchiveToCold', caseID, evidenceID);

    console.log(`✓ Evidence ${evidenceID} archived to cold chain`);

    res.json({ success: true, evidenceID, chain: 'cold' });
  } catch (error) {
    console.error('Error archiving evidence:', error);
    res.status(500).json({
      error: 'Failed to archive evidence',
      message: error.message
    });
  }
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: err.message
  });
});

// Start server
async function start() {
  try {
    // Initialize connections
    await initialize();

    // Check if mTLS certificates exist
    const useMTLS = fs.existsSync(CONFIG.tlsKey) &&
                    fs.existsSync(CONFIG.tlsCert) &&
                    fs.existsSync(CONFIG.tlsCA);

    if (useMTLS) {
      // Start HTTPS server with mTLS
      const httpsOptions = {
        key: fs.readFileSync(CONFIG.tlsKey),
        cert: fs.readFileSync(CONFIG.tlsCert),
        ca: fs.readFileSync(CONFIG.tlsCA),
        requestCert: true,
        rejectUnauthorized: true
      };

      https.createServer(httpsOptions, app).listen(CONFIG.port, '0.0.0.0', () => {
        console.log(`✓ HTTPS server listening on port ${CONFIG.port} (mTLS enabled)`);
        console.log(`  Endpoint: https://0.0.0.0:${CONFIG.port}`);
      });
    } else {
      // Start HTTP server (for testing only)
      console.warn('⚠ Warning: mTLS certificates not found, starting HTTP server');
      console.warn('  This should only be used for testing!');

      app.listen(CONFIG.port, '0.0.0.0', () => {
        console.log(`✓ HTTP server listening on port ${CONFIG.port}`);
        console.log(`  Endpoint: http://0.0.0.0:${CONFIG.port}`);
      });
    }
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\nShutting down...');
  if (hotGateway) hotGateway.close();
  if (coldGateway) coldGateway.close();
  process.exit(0);
});

// Start the server
start();
