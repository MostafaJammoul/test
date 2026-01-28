# -*- coding: utf-8 -*-
#
"""
GUID Resolver Service
Internal DNS-like service for anonymous GUID ↔ identity mapping
"""
import uuid
import hashlib
import logging
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.utils import timezone

from audits.models import OperateLog
from blockchain.models import GUIDMapping

logger = logging.getLogger(__name__)


class GUIDResolver:
    """Internal DNS-like service for GUID resolution"""

    @staticmethod
    def generate_guid(user, anonymity_requested=True):
        """
        Generate privacy-preserving GUID for user

        Args:
            user: User instance
            anonymity_requested: bool - Whether user wants anonymity

        Returns:
            str: Generated GUID or None if not requested
        """
        if not anonymity_requested:
            return None

        # Check if user already has GUID
        if hasattr(user, 'guid_mapping'):
            return user.guid_mapping.guid

        # Generate cryptographically secure GUID
        guid = str(uuid.uuid4())

        # Create commitment (hash) for blockchain
        commitment = hashlib.sha256(
            f"{guid}:{user.id}:{settings.SECRET_KEY}".encode()
        ).hexdigest()

        # Store locally (encrypted in database)
        GUIDMapping.objects.create(
            guid=guid,
            user=user
        )

        logger.info(f"Generated GUID for user {user.username}: {guid[:16]}...")

        # Optionally: Store commitment on blockchain for immutability
        # BlockchainClient.store_commitment(commitment, timestamp)

        return guid

    @staticmethod
    def resolve_guid(guid, requester):
        """
        Resolve GUID to real identity (access controlled)

        Args:
            guid: str - Anonymous GUID
            requester: User - User requesting resolution

        Returns:
            User instance or None

        Raises:
            PermissionDenied: If requester lacks permission
        """
        # Check if requester has permission
        if not requester.has_perm('blockchain.resolve_guid'):
            # Log unauthorized attempt
            OperateLog.objects.create(
                resource_type='GUIDMapping',
                resource='resolution',
                action='resolve',
                user=requester.username,
                remote_addr='',
                diff={
                    'success': False,
                    'detail': f'Unauthorized GUID resolution attempt: {guid[:16]}...'
                }
            )

            logger.warning(
                f"Unauthorized GUID resolution attempt by {requester.username} "
                f"for GUID {guid[:16]}..."
            )

            raise PermissionDenied("Not authorized to resolve GUIDs")

        try:
            mapping = GUIDMapping.objects.select_related('user').get(guid=guid)

            # Audit the resolution (for legal compliance)
            OperateLog.objects.create(
                resource_type='GUIDMapping',
                resource=str(mapping.id),
                action='resolve',
                user=requester.username,
                remote_addr='',
                diff={
                    'success': True,
                    'detail': f'GUID {guid[:16]}... resolved to {mapping.user.username}'
                }
            )

            logger.info(
                f"GUID {guid[:16]}... resolved to {mapping.user.username} "
                f"by {requester.username}"
            )

            return mapping.user

        except GUIDMapping.DoesNotExist:
            logger.error(f"GUID {guid} not found")
            return None

    @staticmethod
    def get_guid_for_user(user):
        """
        Get GUID for user if they have one

        Args:
            user: User instance

        Returns:
            str: GUID or None
        """
        if hasattr(user, 'guid_mapping'):
            return user.guid_mapping.guid
        return None

    @staticmethod
    def revoke_guid(user, requester):
        """
        Revoke user's GUID (admin only)

        Args:
            user: User instance
            requester: User requesting revocation

        Raises:
            PermissionDenied: If requester lacks permission
        """
        if not requester.has_perm('blockchain.delete_guidmapping'):
            raise PermissionDenied("Not authorized to revoke GUIDs")

        if hasattr(user, 'guid_mapping'):
            guid = user.guid_mapping.guid
            user.guid_mapping.delete()

            # Audit the revocation
            OperateLog.objects.create(
                resource_type='GUIDMapping',
                resource=str(user.id),
                action='revoke',
                user=requester.username,
                remote_addr='',
                diff={
                    'success': True,
                    'detail': f'GUID {guid[:16]}... revoked for {user.username}'
                }
            )

            logger.info(f"GUID revoked for user {user.username} by {requester.username}")
