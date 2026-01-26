# -*- coding: utf-8 -*-
#
"""
Hyperledger Fabric REST Client
Communicates with Fabric blockchain via REST API bridge (FYP-2)
"""
import json
import logging
import requests
from django.conf import settings

logger = logging.getLogger(__name__)


class FabricClient:
    """Client for Hyperledger Fabric blockchain operations via REST API"""

    def __init__(self, chain_type='hot'):
        """
        Initialize Fabric REST client

        Args:
            chain_type: 'hot' or 'cold' chain (informational only)
        """
        self.chain_type = chain_type
        self.api_url = settings.FABRIC_API_URL

        # mTLS configuration
        self.cert = None
        if hasattr(settings, 'FABRIC_CLIENT_CERT') and hasattr(settings, 'FABRIC_CLIENT_KEY'):
            self.cert = (settings.FABRIC_CLIENT_CERT, settings.FABRIC_CLIENT_KEY)

        self.verify = getattr(settings, 'FABRIC_CA_CERT', True)

        logger.info(f"Initialized Fabric REST client for {chain_type} chain")
        logger.info(f"API URL: {self.api_url}")
        logger.info(f"mTLS: {self.cert is not None}")

    def _make_request(self, method, endpoint, **kwargs):
        """
        Make HTTP request to Fabric API bridge

        Args:
            method: HTTP method (GET, POST, etc.)
            endpoint: API endpoint path
            **kwargs: Additional request parameters

        Returns:
            dict: Response JSON

        Raises:
            Exception: If request fails
        """
        url = f"{self.api_url}{endpoint}"

        # Add mTLS certificates if configured
        if self.cert:
            kwargs['cert'] = self.cert
        kwargs['verify'] = self.verify

        # Set timeout if not provided
        kwargs.setdefault('timeout', 30)

        try:
            logger.debug(f"{method} {url}")
            response = requests.request(method, url, **kwargs)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.Timeout:
            logger.error(f"Request timeout: {method} {url}")
            raise Exception(f"Blockchain API request timeout")
        except requests.exceptions.ConnectionError as e:
            logger.error(f"Connection error: {method} {url} - {str(e)}")
            raise Exception(f"Cannot connect to blockchain API at {self.api_url}")
        except requests.exceptions.HTTPError as e:
            logger.error(f"HTTP error: {method} {url} - {response.status_code} {response.text}")
            error_data = response.json() if response.headers.get('content-type') == 'application/json' else {}
            raise Exception(error_data.get('message', str(e)))
        except Exception as e:
            logger.error(f"Unexpected error: {method} {url} - {str(e)}")
            raise

    def append_evidence(self, case_id, evidence_id, file_data, file_hash, metadata, user_identifier):
        """
        Append evidence to blockchain (uploads to IPFS + creates blockchain record)

        Args:
            case_id: Case ID (investigation ID)
            evidence_id: UUID of evidence
            file_data: File content as bytes
            file_hash: SHA-256 hash of file
            metadata: Additional metadata dict
            user_identifier: Username or GUID

        Returns:
            dict: Transaction result with cid, tx_id
        """
        try:
            # Add user identifier to metadata
            metadata_with_user = metadata.copy() if metadata else {}
            metadata_with_user['uploaded_by'] = user_identifier

            # Prepare request
            data = {
                'caseID': str(case_id),
                'evidenceID': str(evidence_id),
                'hash': file_hash,
                'metadata': json.dumps(metadata_with_user)
            }

            # Use multipart for file upload
            files = {
                'file': ('evidence.bin', file_data, 'application/octet-stream')
            }

            logger.info(f"Uploading evidence {evidence_id} to blockchain (case: {case_id})...")

            result = self._make_request('POST', '/api/evidence', data=data, files=files)

            logger.info(f"Evidence {evidence_id} uploaded successfully. CID: {result.get('cid')}")

            return {
                'success': True,
                'cid': result.get('cid'),
                'tx_id': result.get('txID'),  # Populated by Fabric
                'block_number': result.get('blockNumber'),
                'chain': result.get('chain', 'hot')
            }

        except Exception as e:
            logger.error(f"Failed to append evidence to blockchain: {str(e)}")
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
            logger.info(f"Querying evidence {evidence_id} from blockchain...")

            result = self._make_request('GET', f'/api/evidence/{evidence_id}')

            logger.info(f"Evidence {evidence_id} found: status={result.get('status')}")

            return result

        except Exception as e:
            logger.error(f"Failed to query evidence: {str(e)}")
            return None

    def query_case_evidence(self, case_id):
        """
        Query all evidence for a case

        Args:
            case_id: Case ID

        Returns:
            list: List of evidence records
        """
        try:
            logger.info(f"Querying evidence for case {case_id}...")

            result = self._make_request('GET', f'/api/evidence/case/{case_id}')

            logger.info(f"Found {len(result)} evidence records for case {case_id}")

            return result

        except Exception as e:
            logger.error(f"Failed to query case evidence: {str(e)}")
            return []

    def transfer_custody(self, case_id, evidence_id, new_owner, reason=''):
        """
        Transfer custody of evidence

        Args:
            case_id: Case ID
            evidence_id: UUID of evidence
            new_owner: New owner username/GUID
            reason: Transfer reason

        Returns:
            dict: Transaction result
        """
        try:
            data = {
                'caseID': str(case_id),
                'newOwner': new_owner,
                'reason': reason
            }

            logger.info(f"Transferring evidence {evidence_id} to {new_owner}...")

            result = self._make_request('POST', f'/api/evidence/{evidence_id}/transfer', json=data)

            logger.info(f"Evidence {evidence_id} transferred successfully")

            return {
                'success': True,
                'tx_id': result.get('txID')
            }

        except Exception as e:
            logger.error(f"Failed to transfer custody: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }

    def archive_evidence(self, case_id, evidence_id):
        """
        Archive evidence to cold chain

        Args:
            case_id: Case ID
            evidence_id: UUID of evidence

        Returns:
            dict: Transaction result
        """
        try:
            data = {
                'caseID': str(case_id)
            }

            logger.info(f"Archiving evidence {evidence_id} to cold chain...")

            result = self._make_request('POST', f'/api/evidence/{evidence_id}/archive', json=data)

            logger.info(f"Evidence {evidence_id} archived successfully")

            return {
                'success': True,
                'chain': 'cold',
                'tx_id': result.get('txID')
            }

        except Exception as e:
            logger.error(f"Failed to archive evidence: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }

    def health_check(self):
        """
        Check if API bridge is healthy

        Returns:
            dict: Health status
        """
        try:
            result = self._make_request('GET', '/api/health')
            return result
        except Exception as e:
            logger.error(f"Health check failed: {str(e)}")
            return {
                'status': 'unhealthy',
                'error': str(e)
            }
