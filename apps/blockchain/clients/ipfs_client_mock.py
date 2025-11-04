# -*- coding: utf-8 -*-
#
"""
Mock IPFS Client - FOR TESTING ONLY
Simulates IPFS operations using local filesystem
"""
import os
import hashlib
import logging
from django.conf import settings
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes

logger = logging.getLogger(__name__)


class IPFSClient:
    """Mock IPFS client that saves to local filesystem instead of IPFS"""

    def __init__(self):
        """Initialize mock IPFS client"""
        self.storage_dir = os.path.join(
            settings.BASE_DIR,
            'data',
            'mock_ipfs'
        )
        os.makedirs(self.storage_dir, exist_ok=True)
        logger.info(f"Mock IPFS client initialized at {self.storage_dir}")

    def upload_evidence(self, file_content, file_name):
        """
        Mock: Upload evidence file (saves locally with encryption)

        Args:
            file_content: Binary file content
            file_name: Original filename

        Returns:
            tuple: (mock_cid, encryption_key_id)
        """
        # Generate mock CID (based on content hash)
        content_hash = hashlib.sha256(file_content).hexdigest()
        mock_cid = f"Qm{content_hash[:44]}"  # Mock CID format

        # Generate encryption key
        encryption_key = get_random_bytes(32)  # AES-256
        encryption_key_id = hashlib.sha256(encryption_key).hexdigest()[:16]

        # Encrypt file content
        cipher = AES.new(encryption_key, AES.MODE_GCM)
        ciphertext, tag = cipher.encrypt_and_digest(file_content)

        # Save encrypted file
        file_path = os.path.join(self.storage_dir, mock_cid)
        with open(file_path, 'wb') as f:
            # Write nonce, tag, and ciphertext
            f.write(cipher.nonce)
            f.write(tag)
            f.write(ciphertext)

        # Save encryption key (in production, use proper key management)
        key_path = os.path.join(self.storage_dir, f"{mock_cid}.key")
        with open(key_path, 'wb') as f:
            f.write(encryption_key)

        # Save metadata
        meta_path = os.path.join(self.storage_dir, f"{mock_cid}.meta")
        with open(meta_path, 'w') as f:
            f.write(f"filename: {file_name}\n")
            f.write(f"size: {len(file_content)}\n")
            f.write(f"encryption_key_id: {encryption_key_id}\n")

        logger.info(f"Mock IPFS upload: {file_name} → {mock_cid}")
        return mock_cid, encryption_key_id

    def retrieve_evidence(self, ipfs_cid, encryption_key_id):
        """
        Mock: Retrieve and decrypt evidence file

        Args:
            ipfs_cid: Mock CID
            encryption_key_id: Encryption key identifier

        Returns:
            bytes: Decrypted file content
        """
        file_path = os.path.join(self.storage_dir, ipfs_cid)

        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File not found: {ipfs_cid}")

        # Read encrypted file
        with open(file_path, 'rb') as f:
            nonce = f.read(16)  # AES-GCM nonce is 16 bytes
            tag = f.read(16)    # AES-GCM tag is 16 bytes
            ciphertext = f.read()

        # Read encryption key
        key_path = os.path.join(self.storage_dir, f"{ipfs_cid}.key")
        with open(key_path, 'rb') as f:
            encryption_key = f.read()

        # Decrypt
        cipher = AES.new(encryption_key, AES.MODE_GCM, nonce=nonce)
        plaintext = cipher.decrypt_and_verify(ciphertext, tag)

        logger.info(f"Mock IPFS retrieve: {ipfs_cid}")
        return plaintext

    def pin_file(self, ipfs_cid):
        """
        Mock: Pin file (mark as important)

        Args:
            ipfs_cid: Mock CID

        Returns:
            bool: Success
        """
        pin_path = os.path.join(self.storage_dir, f"{ipfs_cid}.pinned")
        with open(pin_path, 'w') as f:
            f.write("pinned")

        logger.info(f"Mock IPFS pin: {ipfs_cid}")
        return True

    def get_file_info(self, ipfs_cid):
        """
        Mock: Get file information

        Args:
            ipfs_cid: Mock CID

        Returns:
            dict: File metadata
        """
        meta_path = os.path.join(self.storage_dir, f"{ipfs_cid}.meta")

        if not os.path.exists(meta_path):
            return None

        metadata = {}
        with open(meta_path, 'r') as f:
            for line in f:
                key, value = line.strip().split(': ', 1)
                metadata[key] = value

        return metadata

    def get_storage_info(self):
        """
        Mock: Get storage information

        Returns:
            dict: Storage stats
        """
        files = [f for f in os.listdir(self.storage_dir)
                 if not f.endswith('.key') and not f.endswith('.meta') and not f.endswith('.pinned')]

        total_size = 0
        for f in files:
            file_path = os.path.join(self.storage_dir, f)
            if os.path.isfile(file_path):
                total_size += os.path.getsize(file_path)

        return {
            'file_count': len(files),
            'total_size_bytes': total_size,
            'total_size_mb': round(total_size / (1024 * 1024), 2),
            'storage_path': self.storage_dir,
            'mock': True
        }


# Convenience function to check if file exists
def file_exists(ipfs_cid):
    """Check if file exists in mock storage"""
    storage_dir = os.path.join(settings.BASE_DIR, 'data', 'mock_ipfs')
    file_path = os.path.join(storage_dir, ipfs_cid)
    return os.path.exists(file_path)
