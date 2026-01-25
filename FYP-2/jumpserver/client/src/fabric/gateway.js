/**
 * Fabric Gateway Connection Management
 *
 * Manages connections to Hyperledger Fabric networks (hot and cold chains)
 * using the Fabric Gateway SDK.
 */

import grpc from '@grpc/grpc-js';
import { connect, signers } from '@hyperledger/fabric-gateway';
import crypto from 'crypto';
import fs from 'fs/promises';
import path from 'path';
import { logger } from '../index.js';

class FabricGateway {
  constructor() {
    this.hotChainGateway = null;
    this.coldChainGateway = null;
    this.hotChainClient = null;
    this.coldChainClient = null;
  }

  /**
   * Connect to both hot and cold Fabric networks
   */
  async connect() {
    try {
      // Connect to hot chain
      this.hotChainGateway = await this.connectToChain('hot');
      this.hotChainClient = this.hotChainGateway.getNetwork(process.env.HOT_CHANNEL_NAME || 'evidence-hot');
      logger.info('Connected to hot chain');

      // Connect to cold chain
      this.coldChainGateway = await this.connectToChain('cold');
      this.coldChainClient = this.coldChainGateway.getNetwork(process.env.COLD_CHANNEL_NAME || 'evidence-cold');
      logger.info('Connected to cold chain');

      return true;
    } catch (error) {
      logger.error('Failed to connect to Fabric Gateway:', error);
      throw error;
    }
  }

  /**
   * Connect to a specific chain (hot or cold)
   */
  async connectToChain(chainType) {
    const config = chainType === 'hot' ? {
      peerEndpoint: process.env.HOT_PEER_ENDPOINT || 'localhost:7051',
      peerHostAlias: process.env.HOT_PEER_HOST_ALIAS || 'peer0.lab.hot.dfir.local',
      cryptoPath: process.env.HOT_CRYPTO_PATH || '../../fabric-network/hot-chain/crypto-config',
      mspId: process.env.MSP_ID || 'ForensicLabMSP',
      certPath: process.env.HOT_CERT_PATH,
      keyPath: process.env.HOT_KEY_PATH,
      tlsCertPath: process.env.HOT_TLS_CERT_PATH
    } : {
      peerEndpoint: process.env.COLD_PEER_ENDPOINT || 'localhost:9051',
      peerHostAlias: process.env.COLD_PEER_HOST_ALIAS || 'peer0.lab.cold.dfir.local',
      cryptoPath: process.env.COLD_CRYPTO_PATH || '../../fabric-network/cold-chain/crypto-config',
      mspId: process.env.MSP_ID || 'ForensicLabMSP',
      certPath: process.env.COLD_CERT_PATH,
      keyPath: process.env.COLD_KEY_PATH,
      tlsCertPath: process.env.COLD_TLS_CERT_PATH
    };

    // Load certificates and keys
    const tlsRootCert = await fs.readFile(config.tlsCertPath);
    const credentials = grpc.credentials.createSsl(tlsRootCert);

    // Create gRPC client
    const client = new grpc.Client(config.peerEndpoint, credentials, {
      'grpc.ssl_target_name_override': config.peerHostAlias,
    });

    // Load identity
    const certPem = await fs.readFile(config.certPath);
    const keyPem = await fs.readFile(config.keyPath);

    // Create signer
    const privateKey = crypto.createPrivateKey(keyPem);
    const signer = signers.newPrivateKeySigner(privateKey);

    // Connect to gateway
    const gateway = connect({
      client,
      identity: {
        mspId: config.mspId,
        credentials: certPem,
      },
      signer,
      evaluateOptions: () => {
        return { deadline: Date.now() + 5000 }; // 5 second timeout
      },
      endorseOptions: () => {
        return { deadline: Date.now() + 15000 }; // 15 second timeout
      },
      submitOptions: () => {
        return { deadline: Date.now() + 30000 }; // 30 second timeout
      },
      commitStatusOptions: () => {
        return { deadline: Date.now() + 60000 }; // 60 second timeout
      },
    });

    return gateway;
  }

  /**
   * Get contract for hot chain
   */
  getHotContract(contractName = 'custody') {
    if (!this.hotChainClient) {
      throw new Error('Hot chain not connected');
    }
    return this.hotChainClient.getContract(contractName);
  }

  /**
   * Get contract for cold chain
   */
  getColdContract(contractName = 'custody') {
    if (!this.coldChainClient) {
      throw new Error('Cold chain not connected');
    }
    return this.coldChainClient.getContract(contractName);
  }

  /**
   * Submit transaction to hot chain
   */
  async submitToHot(contractName, functionName, ...args) {
    try {
      const contract = this.getHotContract(contractName);
      const resultBytes = await contract.submitTransaction(functionName, ...args);
      return JSON.parse(resultBytes.toString());
    } catch (error) {
      logger.error(`Error submitting transaction to hot chain: ${functionName}`, error);
      throw error;
    }
  }

  /**
   * Submit transaction to cold chain
   */
  async submitToCold(contractName, functionName, ...args) {
    try {
      const contract = this.getColdContract(contractName);
      const resultBytes = await contract.submitTransaction(functionName, ...args);
      return JSON.parse(resultBytes.toString());
    } catch (error) {
      logger.error(`Error submitting transaction to cold chain: ${functionName}`, error);
      throw error;
    }
  }

  /**
   * Evaluate transaction on hot chain (read-only)
   */
  async evaluateHot(contractName, functionName, ...args) {
    try {
      const contract = this.getHotContract(contractName);
      const resultBytes = await contract.evaluateTransaction(functionName, ...args);
      return JSON.parse(resultBytes.toString());
    } catch (error) {
      logger.error(`Error evaluating transaction on hot chain: ${functionName}`, error);
      throw error;
    }
  }

  /**
   * Evaluate transaction on cold chain (read-only)
   */
  async evaluateCold(contractName, functionName, ...args) {
    try {
      const contract = this.getColdContract(contractName);
      const resultBytes = await contract.evaluateTransaction(functionName, ...args);
      return JSON.parse(resultBytes.toString());
    } catch (error) {
      logger.error(`Error evaluating transaction on cold chain: ${functionName}`, error);
      throw error;
    }
  }

  /**
   * Disconnect from Fabric networks
   */
  async disconnect() {
    try {
      if (this.hotChainGateway) {
        this.hotChainGateway.close();
        this.hotChainClient.close();
        logger.info('Disconnected from hot chain');
      }

      if (this.coldChainGateway) {
        this.coldChainGateway.close();
        this.coldChainClient.close();
        logger.info('Disconnected from cold chain');
      }
    } catch (error) {
      logger.error('Error disconnecting from Fabric:', error);
    }
  }
}

// Export singleton instance
const fabricGateway = new FabricGateway();
export default fabricGateway;
