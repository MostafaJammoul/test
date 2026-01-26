# -*- coding: utf-8 -*-
#
"""
Hyperledger Fabric REST API Client
Handles communication with FYP-2 blockchain via REST API with mTLS
"""
import json
import logging
import requests
from django.conf import settings

logger = logging.getLogger(__name__)


class FabricClient:
    """Client for Hyperledger Fabric blockchain operations via REST API"""

    def __init__(self):
        """
        Initialize Fabric REST API client with mTLS configuration
        """
        # API endpoint
        self.api_url = getattr(settings, 'FABRIC_API_URL', 'https://localhost:3001')

        # mTLS certificates
        self.client_cert = getattr(settings, 'FABRIC_CLIENT_CERT', None)
        self.client_key = getattr(settings, 'FABRIC_CLIENT_KEY', None)
        self.ca_cert = getattr(settings, 'FABRIC_CA_CERT', None)

        # Verify configuration
        if not all([self.client_cert, self.client_key, self.ca_cert]):
            logger.warning("mTLS certificates not configured. API calls will fail.")

        # Create requests session with mTLS
        self.session = requests.Session()
        if self.client_cert and self.client_key:
            self.session.cert = (self.client_cert, self.client_key)
        if self.ca_cert:
            self.session.verify = self.ca_cert

    def _make_request(self, method, endpoint, **kwargs):
        """
        Make authenticated request to API bridge

        Args:
            method: HTTP method (GET, POST, etc.)
            endpoint: API endpoint path (e.g., '/api/health')
            **kwargs: Additional arguments for requests

        Returns:
            dict: Response JSON

        Raises:
            Exception: If request fails
        """
        url = f"{self.api_url}{endpoint}"

        try:
            response = self.session.request(method, url, **kwargs)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.SSLError as e:
            logger.error(f"mTLS certificate error: {e}")
            raise Exception(f"Certificate authentication failed: {e}")
        except requests.exceptions.RequestException as e:
            logger.error(f"API request failed: {e}")
            raise Exception(f"Blockchain API error: {e}")

    def health_check(self):
        """
        Check API bridge health and blockchain connectivity

        Returns:
            dict: Health status with blockchain connections
        """
        return self._make_request('GET', '/api/health')

    def append_evidence(self, case_id, evidence_id, file_data, file_hash, metadata, user_identifier):
        """
        Append evidence to blockchain (uploads to IPFS automatically)

        Args:
            case_id: Investigation case ID
            evidence_id: Unique evidence identifier (UUID)
            file_data: Binary file data (bytes)
            file_hash: SHA-256 hash of file
            metadata: Dict with evidence metadata
            user_identifier: Username or user ID for audit trail

        Returns:
            dict: Result with IPFS CID and transaction ID
        """
        # Add user attribution to metadata for audit trail
        metadata_with_user = {
            **metadata,
            'collected_by': user_identifier,
            'jumpserver_user': user_identifier
        }

        # Prepare multipart form data
        data = {
            'caseID': str(case_id),
            'evidenceID': str(evidence_id),
            'hash': file_hash,
            'metadata': json.dumps(metadata_with_user)
        }

        files = {
            'file': ('evidence.bin', file_data, 'application/octet-stream')
        }

        logger.info(f"Appending evidence {evidence_id} for case {case_id} by user {user_identifier}")
        result = self._make_request('POST', '/api/evidence', data=data, files=files)

        logger.info(f"Evidence {evidence_id} appended to blockchain. CID: {result.get('cid')}")
        return {
            'success': True,
            'cid': result.get('cid'),
            'tx_id': result.get('txID'),
            'chain': result.get('chain', 'hot')
        }

    def query_evidence(self, evidence_id):
        """
        Query evidence by ID from blockchain

        Args:
            evidence_id: Evidence identifier

        Returns:
            dict: Evidence details including CID, hash, status, owner
        """
        logger.info(f"Querying evidence {evidence_id}")
        return self._make_request('GET', f'/api/evidence/{evidence_id}')

    def query_case_evidence(self, case_id):
        """
        Query all evidence for a case

        Args:
            case_id: Case identifier

        Returns:
            list: List of evidence items
        """
        logger.info(f"Querying evidence for case {case_id}")
        return self._make_request('GET', f'/api/evidence/case/{case_id}')

    def transfer_custody(self, case_id, evidence_id, new_owner, reason, user_identifier):
        """
        Transfer custody of evidence to new owner

        Args:
            case_id: Case ID
            evidence_id: Evidence ID
            new_owner: New owner username/ID
            reason: Reason for transfer
            user_identifier: User performing the transfer

        Returns:
            dict: Transfer result
        """
        data = {
            'caseID': str(case_id),
            'newOwner': new_owner,
            'reason': f"{reason} (by {user_identifier})"
        }

        logger.info(f"Transferring custody of {evidence_id} to {new_owner} by {user_identifier}")
        result = self._make_request('POST', f'/api/evidence/{evidence_id}/transfer', json=data)

        logger.info(f"Custody of {evidence_id} transferred to {new_owner}")
        return result

    def archive_evidence(self, case_id, evidence_id, user_identifier):
        """
        Archive evidence to cold chain

        Args:
            case_id: Case ID
            evidence_id: Evidence ID
            user_identifier: User performing the archive

        Returns:
            dict: Archive result
        """
        data = {
            'caseID': str(case_id)
        }

        logger.info(f"Archiving evidence {evidence_id} to cold chain by {user_identifier}")
        result = self._make_request('POST', f'/api/evidence/{evidence_id}/archive', json=data)

        logger.info(f"Evidence {evidence_id} archived to cold chain")
        return result
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
