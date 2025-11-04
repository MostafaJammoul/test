# -*- coding: utf-8 -*-
#
"""
IPFS Client
Handles encrypted file storage on IPFS with mTLS
"""
import logging
import ssl
from io import BytesIO
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
from Crypto.Protocol.KDF import PBKDF2
import ipfshttpclient
from django.conf import settings

logger = logging.getLogger(__name__)


class IPFSClient:
    """Client for IPFS operations with encryption and mTLS"""

    def __init__(self):
        """Initialize IPFS client with mTLS configuration"""
        self._client = None
        self._connect()

    def _connect(self):
        """Connect to IPFS with mTLS"""
        try:
            # Create SSL context for mTLS
            ssl_context = ssl.create_default_context(
                cafile=settings.IPFS_CA_CERT_PATH
            )
            ssl_context.load_cert_chain(
                certfile=settings.IPFS_CLIENT_CERT_PATH,
                keyfile=settings.IPFS_CLIENT_KEY_PATH
            )

            # Connect to IPFS gateway with mTLS
            self._client = ipfshttpclient.connect(
                settings.IPFS_GATEWAY_URL,
                session_options={'timeout': 300, 'cert': ssl_context}
            )

            logger.info("Connected to IPFS successfully")

        except Exception as e:
            logger.error(f"Failed to connect to IPFS: {str(e)}")
            raise

    def encrypt_file(self, file_data, encryption_key=None):
        """
        Encrypt file data before uploading to IPFS

        Args:
            file_data: bytes - File content
            encryption_key: str - Encryption key (generated if not provided)

        Returns:
            tuple: (encrypted_data, encryption_key_id)
        """
        if encryption_key is None:
            # Generate random encryption key
            encryption_key = get_random_bytes(32)  # 256-bit key

        # Derive key using PBKDF2
        salt = get_random_bytes(16)
        key = PBKDF2(encryption_key, salt, dkLen=32)

        # Encrypt using AES-256 in GCM mode
        cipher = AES.new(key, AES.MODE_GCM)
        ciphertext, tag = cipher.encrypt_and_digest(file_data)

        # Combine salt + nonce + tag + ciphertext
        encrypted_data = salt + cipher.nonce + tag + ciphertext

        # Store encryption key securely (you should use a key management service)
        encryption_key_id = self._store_encryption_key(encryption_key)

        return encrypted_data, encryption_key_id

    def decrypt_file(self, encrypted_data, encryption_key_id):
        """
        Decrypt file data retrieved from IPFS

        Args:
            encrypted_data: bytes - Encrypted file content
            encryption_key_id: str - Key ID to retrieve encryption key

        Returns:
            bytes: Decrypted file content
        """
        # Retrieve encryption key
        encryption_key = self._retrieve_encryption_key(encryption_key_id)

        # Extract components
        salt = encrypted_data[:16]
        nonce = encrypted_data[16:32]
        tag = encrypted_data[32:48]
        ciphertext = encrypted_data[48:]

        # Derive key
        key = PBKDF2(encryption_key, salt, dkLen=32)

        # Decrypt
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        plaintext = cipher.decrypt_and_verify(ciphertext, tag)

        return plaintext

    def _store_encryption_key(self, encryption_key):
        """
        Store encryption key securely
        In production, use AWS KMS, Azure Key Vault, or HashiCorp Vault

        Args:
            encryption_key: bytes - Encryption key

        Returns:
            str: Key ID
        """
        # TODO: Integrate with key management service
        # For now, return hex representation (NOT SECURE FOR PRODUCTION)
        import uuid
        key_id = str(uuid.uuid4())

        # Store in secure key vault (implement based on your KMS)
        # For demo: store in encrypted database field
        logger.warning("Using demo key storage - implement proper KMS for production")

        return key_id

    def _retrieve_encryption_key(self, encryption_key_id):
        """
        Retrieve encryption key from secure storage

        Args:
            encryption_key_id: str - Key ID

        Returns:
            bytes: Encryption key
        """
        # TODO: Retrieve from key management service
        # For now, return None (will fail decryption)
        logger.warning("Key retrieval not implemented - integrate with KMS")
        return None

    def upload_evidence(self, file_data, metadata=None, encrypt=True):
        """
        Upload evidence to IPFS (encrypted)

        Args:
            file_data: bytes - File content
            metadata: dict - Additional metadata
            encrypt: bool - Whether to encrypt before upload

        Returns:
            dict: {
                'cid': IPFS CID,
                'size': File size,
                'encryption_key_id': Encryption key ID (if encrypted)
            }
        """
        try:
            encryption_key_id = None

            if encrypt:
                file_data, encryption_key_id = self.encrypt_file(file_data)

            # Upload to IPFS
            result = self._client.add(BytesIO(file_data))
            cid = result['Hash']

            # Pin to prevent garbage collection
            self._client.pin.add(cid)

            logger.info(f"Evidence uploaded to IPFS. CID: {cid}")

            return {
                'success': True,
                'cid': cid,
                'size': result['Size'],
                'encryption_key_id': encryption_key_id
            }

        except Exception as e:
            logger.error(f"Failed to upload evidence to IPFS: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }

    def retrieve_evidence(self, cid, encryption_key_id=None):
        """
        Retrieve evidence from IPFS (and decrypt if encrypted)

        Args:
            cid: str - IPFS content identifier
            encryption_key_id: str - Encryption key ID (if encrypted)

        Returns:
            bytes: File content (decrypted if encrypted)
        """
        try:
            # Retrieve from IPFS
            file_data = self._client.cat(cid)

            # Decrypt if encryption key provided
            if encryption_key_id:
                file_data = self.decrypt_file(file_data, encryption_key_id)

            logger.info(f"Evidence retrieved from IPFS. CID: {cid}")

            return file_data

        except Exception as e:
            logger.error(f"Failed to retrieve evidence from IPFS: {str(e)}")
            return None

    def verify_cid(self, cid):
        """
        Verify that a CID exists and is pinned

        Args:
            cid: str - IPFS content identifier

        Returns:
            bool: True if exists and pinned, False otherwise
        """
        try:
            # Check if pinned
            pins = self._client.pin.ls(cid)
            return cid in pins['Keys']

        except Exception as e:
            logger.error(f"Failed to verify CID on IPFS: {str(e)}")
            return False

    def get_file_stats(self, cid):
        """
        Get statistics about a file on IPFS

        Args:
            cid: str - IPFS content identifier

        Returns:
            dict: File statistics
        """
        try:
            stats = self._client.object.stat(cid)
            return {
                'size': stats['CumulativeSize'],
                'num_links': stats['NumLinks'],
                'block_size': stats['BlockSize']
            }

        except Exception as e:
            logger.error(f"Failed to get file stats from IPFS: {str(e)}")
            return None
