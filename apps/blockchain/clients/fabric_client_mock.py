# -*- coding: utf-8 -*-
#
"""
Mock Hyperledger Fabric Client - FOR TESTING ONLY
Simulates blockchain operations using local filesystem
"""
import json
import os
import hashlib
import logging
from datetime import datetime
from django.conf import settings

logger = logging.getLogger(__name__)


class FabricClient:
    """Mock Fabric client that saves to local filesystem instead of blockchain"""

    def __init__(self, chain_type='hot'):
        """
        Initialize mock Fabric client

        Args:
            chain_type: 'hot' or 'cold' chain
        """
        self.chain_type = chain_type
        self.storage_dir = os.path.join(
            settings.BASE_DIR,
            'data',
            'mock_blockchain',
            chain_type
        )
        os.makedirs(self.storage_dir, exist_ok=True)
        logger.info(f"Mock Fabric client initialized for {chain_type} chain at {self.storage_dir}")

    def append_evidence(self, chain, evidence_hash, ipfs_cid, user, investigation_id, metadata=None):
        """
        Mock: Append evidence to chain (saves to local file)

        Args:
            chain: 'hot' or 'cold'
            evidence_hash: SHA-256 hash of evidence file
            ipfs_cid: IPFS content identifier (mock)
            user: Username or GUID
            investigation_id: Investigation UUID
            metadata: Additional metadata dict

        Returns:
            str: Mock transaction hash
        """
        # Generate mock transaction hash
        tx_data = f"{evidence_hash}{ipfs_cid}{user}{datetime.utcnow().isoformat()}"
        tx_hash = hashlib.sha256(tx_data.encode()).hexdigest()

        # Create transaction record
        transaction = {
            'tx_hash': tx_hash,
            'chain': chain,
            'evidence_hash': evidence_hash,
            'ipfs_cid': ipfs_cid,
            'user': user,
            'investigation_id': investigation_id,
            'metadata': metadata or {},
            'timestamp': datetime.utcnow().isoformat(),
            'block_number': self._get_next_block_number()
        }

        # Save to file
        tx_file = os.path.join(self.storage_dir, f"{tx_hash}.json")
        with open(tx_file, 'w') as f:
            json.dump(transaction, f, indent=2)

        logger.info(f"Mock transaction saved: {tx_hash} ({chain} chain)")
        return tx_hash

    def query_evidence(self, tx_hash):
        """
        Mock: Query evidence by transaction hash

        Args:
            tx_hash: Transaction hash to query

        Returns:
            dict: Transaction data or None if not found
        """
        tx_file = os.path.join(self.storage_dir, f"{tx_hash}.json")

        if not os.path.exists(tx_file):
            # Try other chain
            other_chain = 'cold' if self.chain_type == 'hot' else 'hot'
            other_dir = os.path.join(
                settings.BASE_DIR,
                'data',
                'mock_blockchain',
                other_chain
            )
            tx_file = os.path.join(other_dir, f"{tx_hash}.json")

        if os.path.exists(tx_file):
            with open(tx_file, 'r') as f:
                return json.load(f)

        return None

    def verify_evidence(self, tx_hash, evidence_hash):
        """
        Mock: Verify evidence integrity

        Args:
            tx_hash: Transaction hash
            evidence_hash: Expected evidence hash

        Returns:
            bool: True if hashes match
        """
        transaction = self.query_evidence(tx_hash)
        if not transaction:
            return False

        return transaction['evidence_hash'] == evidence_hash

    def archive_to_cold_chain(self, hot_chain_tx_hash):
        """
        Mock: Archive from hot to cold chain

        Args:
            hot_chain_tx_hash: Transaction hash from hot chain

        Returns:
            str: Cold chain transaction hash
        """
        # Get transaction from hot chain
        hot_dir = os.path.join(settings.BASE_DIR, 'data', 'mock_blockchain', 'hot')
        hot_file = os.path.join(hot_dir, f"{hot_chain_tx_hash}.json")

        if not os.path.exists(hot_file):
            raise ValueError(f"Transaction {hot_chain_tx_hash} not found in hot chain")

        with open(hot_file, 'r') as f:
            transaction = json.load(f)

        # Create cold chain transaction
        cold_tx_data = f"{hot_chain_tx_hash}cold{datetime.utcnow().isoformat()}"
        cold_tx_hash = hashlib.sha256(cold_tx_data.encode()).hexdigest()

        transaction['original_hot_tx'] = hot_chain_tx_hash
        transaction['archived_at'] = datetime.utcnow().isoformat()
        transaction['tx_hash'] = cold_tx_hash
        transaction['chain'] = 'cold'

        # Save to cold chain
        cold_dir = os.path.join(settings.BASE_DIR, 'data', 'mock_blockchain', 'cold')
        os.makedirs(cold_dir, exist_ok=True)
        cold_file = os.path.join(cold_dir, f"{cold_tx_hash}.json")

        with open(cold_file, 'w') as f:
            json.dump(transaction, f, indent=2)

        logger.info(f"Mock archive: {hot_chain_tx_hash} → {cold_tx_hash}")
        return cold_tx_hash

    def create_investigation(self, case_number, user):
        """
        Mock: Create investigation record on blockchain

        Args:
            case_number: Investigation case number
            user: Username

        Returns:
            str: Transaction hash
        """
        tx_data = f"{case_number}{user}{datetime.utcnow().isoformat()}"
        tx_hash = hashlib.sha256(tx_data.encode()).hexdigest()

        investigation = {
            'tx_hash': tx_hash,
            'case_number': case_number,
            'created_by': user,
            'created_at': datetime.utcnow().isoformat(),
            'type': 'investigation_created'
        }

        tx_file = os.path.join(self.storage_dir, f"inv_{tx_hash}.json")
        with open(tx_file, 'w') as f:
            json.dump(investigation, f, indent=2)

        logger.info(f"Mock investigation created: {case_number}")
        return tx_hash

    def reopen_investigation(self, case_number, user):
        """
        Mock: Log investigation reopening

        Args:
            case_number: Investigation case number
            user: Username

        Returns:
            str: Transaction hash
        """
        tx_data = f"reopen{case_number}{user}{datetime.utcnow().isoformat()}"
        tx_hash = hashlib.sha256(tx_data.encode()).hexdigest()

        reopen = {
            'tx_hash': tx_hash,
            'case_number': case_number,
            'reopened_by': user,
            'reopened_at': datetime.utcnow().isoformat(),
            'type': 'investigation_reopened'
        }

        tx_file = os.path.join(self.storage_dir, f"reopen_{tx_hash}.json")
        with open(tx_file, 'w') as f:
            json.dump(reopen, f, indent=2)

        logger.info(f"Mock investigation reopened: {case_number}")
        return tx_hash

    def _get_next_block_number(self):
        """Get next block number (mock)"""
        # Count files in directory
        files = [f for f in os.listdir(self.storage_dir) if f.endswith('.json')]
        return len(files) + 1

    def get_chain_info(self):
        """
        Mock: Get blockchain info

        Returns:
            dict: Chain information
        """
        files = [f for f in os.listdir(self.storage_dir) if f.endswith('.json')]
        return {
            'chain': self.chain_type,
            'height': len(files),
            'storage_path': self.storage_dir,
            'mock': True
        }
