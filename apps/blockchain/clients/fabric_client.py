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

    def query_evidence(self, evidence_id, case_id):
        """
        Query evidence by ID from blockchain

        Args:
            evidence_id: Evidence identifier
            case_id: Case identifier (required for composite key lookup)

        Returns:
            dict: Evidence details including CID, hash, status, owner
        """
        logger.info(f"Querying evidence {evidence_id} for case {case_id}")
        return self._make_request('GET', f'/api/evidence/{evidence_id}?caseID={case_id}')

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
