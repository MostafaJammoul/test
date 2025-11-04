# -*- coding: utf-8 -*-
#
"""
Hyperledger Fabric Client
Handles communication with Fabric blockchain (hot and cold chains)
"""
import json
import logging
from django.conf import settings
from hfc.fabric import Client
from hfc.util.keyvaluestore import FileKeyValueStore

logger = logging.getLogger(__name__)


class FabricClient:
    """Client for Hyperledger Fabric blockchain operations"""

    def __init__(self, chain_type='hot'):
        """
        Initialize Fabric client

        Args:
            chain_type: 'hot' or 'cold' chain
        """
        self.chain_type = chain_type
        self.client = Client(net_profile=self._get_network_profile())

        # Set up client with user context
        self._setup_client()

    def _get_network_profile(self):
        """Get network connection profile based on chain type"""
        if self.chain_type == 'hot':
            return settings.FABRIC_HOT_CHAIN_PROFILE
        else:
            return settings.FABRIC_COLD_CHAIN_PROFILE

    def _setup_client(self):
        """Set up Fabric client with user context and mTLS credentials"""
        try:
            # Set up key-value store for user credentials
            kv_store_path = settings.FABRIC_KEYVALUE_STORE_PATH
            self.client.state_store = FileKeyValueStore(kv_store_path)

            # Get admin user from CA (with mTLS certificates)
            admin_name = settings.FABRIC_ADMIN_NAME
            org_name = settings.FABRIC_ORG_NAME

            # Load user context (includes client cert/key for mTLS)
            self.client.get_user(org_name, admin_name)

        except Exception as e:
            logger.error(f"Failed to setup Fabric client: {str(e)}")
            raise

    def append_evidence(self, evidence_id, ipfs_cid, file_hash, metadata, user_identifier):
        """
        Append evidence to blockchain

        Args:
            evidence_id: UUID of evidence
            ipfs_cid: IPFS content identifier
            file_hash: SHA-256 hash of file
            metadata: Additional metadata dict
            user_identifier: Username or GUID

        Returns:
            dict: Transaction result with tx_id, block_number
        """
        try:
            # Get channel
            channel_name = 'evidence-hot-channel' if self.chain_type == 'hot' else 'evidence-cold-channel'
            channel = self.client.get_channel(channel_name)

            # Prepare chaincode arguments
            chaincode_name = 'evidence-hot' if self.chain_type == 'hot' else 'evidence-cold'
            args = [
                str(evidence_id),
                ipfs_cid,
                file_hash,
                json.dumps(metadata),
                user_identifier,
                str(int(timezone.now().timestamp()))
            ]

            # Invoke chaincode
            response = channel.chaincode_invoke(
                requestor=self.client.get_user(settings.FABRIC_ORG_NAME, settings.FABRIC_ADMIN_NAME),
                channel_name=channel_name,
                peers=['peer0.org1.example.com'],  # Configure based on your network
                fcn='appendEvidence',
                args=args,
                cc_name=chaincode_name,
                wait_for_event=True
            )

            tx_id = response.response[0]['txId']

            logger.info(f"Evidence {evidence_id} appended to {self.chain_type} chain. TxID: {tx_id}")

            return {
                'success': True,
                'tx_id': tx_id,
                'block_number': None  # Will be set after confirmation
            }

        except Exception as e:
            logger.error(f"Failed to append evidence to {self.chain_type} chain: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }

    def query_evidence(self, evidence_id):
        """
        Query evidence from blockchain

        Args:
            evidence_id: UUID of evidence

        Returns:
            dict: Evidence data from blockchain
        """
        try:
            channel_name = 'evidence-hot-channel' if self.chain_type == 'hot' else 'evidence-cold-channel'
            channel = self.client.get_channel(channel_name)

            chaincode_name = 'evidence-hot' if self.chain_type == 'hot' else 'evidence-cold'

            response = channel.chaincode_query(
                requestor=self.client.get_user(settings.FABRIC_ORG_NAME, settings.FABRIC_ADMIN_NAME),
                channel_name=channel_name,
                peers=['peer0.org1.example.com'],
                fcn='queryEvidence',
                args=[str(evidence_id)],
                cc_name=chaincode_name
            )

            return json.loads(response)

        except Exception as e:
            logger.error(f"Failed to query evidence from {self.chain_type} chain: {str(e)}")
            return None

    def verify_evidence(self, evidence_id, file_hash):
        """
        Verify evidence integrity on blockchain

        Args:
            evidence_id: UUID of evidence
            file_hash: SHA-256 hash to verify

        Returns:
            bool: True if hash matches, False otherwise
        """
        try:
            channel_name = 'evidence-hot-channel' if self.chain_type == 'hot' else 'evidence-cold-channel'
            channel = self.client.get_channel(channel_name)

            chaincode_name = 'evidence-hot' if self.chain_type == 'hot' else 'evidence-cold'

            response = channel.chaincode_query(
                requestor=self.client.get_user(settings.FABRIC_ORG_NAME, settings.FABRIC_ADMIN_NAME),
                channel_name=channel_name,
                peers=['peer0.org1.example.com'],
                fcn='verifyEvidence',
                args=[str(evidence_id), file_hash],
                cc_name=chaincode_name
            )

            result = json.loads(response)
            return result.get('valid', False)

        except Exception as e:
            logger.error(f"Failed to verify evidence on {self.chain_type} chain: {str(e)}")
            return False

    def get_evidence_history(self, evidence_id):
        """
        Get complete history of evidence (all modifications)

        Args:
            evidence_id: UUID of evidence

        Returns:
            list: History records
        """
        try:
            channel_name = 'evidence-hot-channel' if self.chain_type == 'hot' else 'evidence-cold-channel'
            channel = self.client.get_channel(channel_name)

            chaincode_name = 'evidence-hot' if self.chain_type == 'hot' else 'evidence-cold'

            response = channel.chaincode_query(
                requestor=self.client.get_user(settings.FABRIC_ORG_NAME, settings.FABRIC_ADMIN_NAME),
                channel_name=channel_name,
                peers=['peer0.org1.example.com'],
                fcn='getEvidenceHistory',
                args=[str(evidence_id)],
                cc_name=chaincode_name
            )

            return json.loads(response)

        except Exception as e:
            logger.error(f"Failed to get evidence history from {self.chain_type} chain: {str(e)}")
            return []

    def archive_to_cold_chain(self, evidence_id, hot_chain_tx_id, ipfs_cid, archived_by):
        """
        Archive evidence from hot chain to cold chain (only for cold chain client)

        Args:
            evidence_id: UUID of evidence
            hot_chain_tx_id: Transaction ID from hot chain
            ipfs_cid: IPFS CID
            archived_by: User who archived

        Returns:
            dict: Archive transaction result
        """
        if self.chain_type != 'cold':
            raise ValueError("This method only available for cold chain client")

        try:
            channel = self.client.get_channel('evidence-cold-channel')

            args = [
                str(evidence_id),
                hot_chain_tx_id,
                ipfs_cid,
                archived_by,
                str(int(timezone.now().timestamp()))
            ]

            response = channel.chaincode_invoke(
                requestor=self.client.get_user(settings.FABRIC_ORG_NAME, settings.FABRIC_ADMIN_NAME),
                channel_name='evidence-cold-channel',
                peers=['peer0.org1.example.com'],
                fcn='archiveEvidence',
                args=args,
                cc_name='evidence-cold',
                wait_for_event=True
            )

            tx_id = response.response[0]['txId']

            logger.info(f"Evidence {evidence_id} archived to cold chain. TxID: {tx_id}")

            return {
                'success': True,
                'tx_id': tx_id
            }

        except Exception as e:
            logger.error(f"Failed to archive evidence to cold chain: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }

    def reopen_case(self, investigation_id, reopened_by, reason):
        """
        Log case reopening on cold chain

        Args:
            investigation_id: UUID of investigation
            reopened_by: User who reopened
            reason: Reason for reopening

        Returns:
            dict: Transaction result
        """
        if self.chain_type != 'cold':
            raise ValueError("This method only available for cold chain client")

        try:
            channel = self.client.get_channel('evidence-cold-channel')

            args = [
                str(investigation_id),
                reopened_by,
                reason,
                str(int(timezone.now().timestamp()))
            ]

            response = channel.chaincode_invoke(
                requestor=self.client.get_user(settings.FABRIC_ORG_NAME, settings.FABRIC_ADMIN_NAME),
                channel_name='evidence-cold-channel',
                peers=['peer0.org1.example.com'],
                fcn='reopenCase',
                args=args,
                cc_name='evidence-cold',
                wait_for_event=True
            )

            tx_id = response.response[0]['txId']

            logger.info(f"Case {investigation_id} reopened. TxID: {tx_id}")

            return {
                'success': True,
                'tx_id': tx_id
            }

        except Exception as e:
            logger.error(f"Failed to log case reopening: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }
