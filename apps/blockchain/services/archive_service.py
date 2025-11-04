# -*- coding: utf-8 -*-
#
"""
Evidence Archival Service
Handles archiving from hot chain to cold chain (Court role only)
"""
import logging
from django.utils import timezone
from django.core.exceptions import PermissionDenied

from blockchain.models import Investigation, BlockchainTransaction
from blockchain.clients import FabricClient
from audits.models import OperateLog

logger = logging.getLogger(__name__)


class ArchiveService:
    """Service for archiving investigations from hot to cold chain"""

    @staticmethod
    def archive_investigation(investigation_id, archived_by):
        """
        Archive completed investigation from hot to cold chain
        Only Court role can perform this action

        Args:
            investigation_id: UUID of investigation
            archived_by: User performing archival (must have Court role)

        Returns:
            dict: Result with success status and details

        Raises:
            PermissionDenied: If user lacks Court role
        """
        # Check permission (Court role only)
        if not archived_by.has_perm('blockchain.archive_investigation'):
            logger.warning(
                f"Unauthorized archive attempt by {archived_by.username} "
                f"for investigation {investigation_id}"
            )
            raise PermissionDenied("Only Court role can archive investigations")

        try:
            investigation = Investigation.objects.get(id=investigation_id)

            if investigation.status == 'archived':
                return {
                    'success': False,
                    'error': 'Investigation already archived'
                }

            # Get all hot chain transactions for this investigation
            hot_transactions = BlockchainTransaction.objects.filter(
                investigation=investigation,
                chain_type='hot'
            )

            # Initialize cold chain client
            cold_chain_client = FabricClient(chain_type='cold')

            archived_count = 0

            # Archive each evidence to cold chain
            for hot_tx in hot_transactions:
                result = cold_chain_client.archive_to_cold_chain(
                    evidence_id=hot_tx.id,
                    hot_chain_tx_id=hot_tx.transaction_hash,
                    ipfs_cid=hot_tx.ipfs_cid,
                    archived_by=archived_by.username
                )

                if result['success']:
                    # Record cold chain transaction
                    BlockchainTransaction.objects.create(
                        investigation=investigation,
                        transaction_hash=result['tx_id'],
                        chain_type='cold',
                        evidence_hash=hot_tx.evidence_hash,
                        ipfs_cid=hot_tx.ipfs_cid,
                        user=archived_by,
                        merkle_root=hot_tx.merkle_root,
                        metadata={
                            'hot_chain_tx': hot_tx.transaction_hash,
                            'archived_at': timezone.now().isoformat(),
                            'investigation_id': str(investigation_id)
                        }
                    )
                    archived_count += 1

            # Mark investigation as archived
            investigation.status = 'archived'
            investigation.archived_by = archived_by
            investigation.archived_at = timezone.now()
            investigation.save(update_fields=['status', 'archived_by', 'archived_at'])

            # Audit log
            OperateLog.objects.create(
                resource_type='Investigation',
                resource=str(investigation_id),
                action='archive',
                user=archived_by.username,
                remote_addr='',
                is_success=True,
                detail=f'Investigation {investigation.case_number} archived. {archived_count} evidence items moved to cold chain.'
            )

            logger.info(
                f"Investigation {investigation.case_number} archived by {archived_by.username}. "
                f"{archived_count} items to cold chain."
            )

            return {
                'success': True,
                'archived_count': archived_count,
                'investigation': investigation.case_number
            }

        except Investigation.DoesNotExist:
            logger.error(f"Investigation {investigation_id} not found")
            return {
                'success': False,
                'error': 'Investigation not found'
            }
        except Exception as e:
            logger.error(f"Failed to archive investigation: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }

    @staticmethod
    def reopen_investigation(investigation_id, reopened_by, reason):
        """
        Reopen archived investigation
        Evidence remains in both hot and cold chains

        Args:
            investigation_id: UUID of investigation
            reopened_by: User reopening (must have Court role)
            reason: Reason for reopening

        Returns:
            dict: Result with success status

        Raises:
            PermissionDenied: If user lacks Court role
        """
        # Check permission (Court role only)
        if not reopened_by.has_perm('blockchain.reopen_investigation'):
            logger.warning(
                f"Unauthorized reopen attempt by {reopened_by.username} "
                f"for investigation {investigation_id}"
            )
            raise PermissionDenied("Only Court role can reopen investigations")

        try:
            investigation = Investigation.objects.get(id=investigation_id)

            if investigation.status != 'archived':
                return {
                    'success': False,
                    'error': 'Investigation is not archived'
                }

            # Mark as active
            investigation.status = 'active'
            investigation.reopened_by = reopened_by
            investigation.reopened_at = timezone.now()
            investigation.reopen_reason = reason
            investigation.save(update_fields=['status', 'reopened_by', 'reopened_at', 'reopen_reason'])

            # Log to cold chain
            cold_chain_client = FabricClient(chain_type='cold')
            result = cold_chain_client.reopen_case(
                investigation_id=investigation_id,
                reopened_by=reopened_by.username,
                reason=reason
            )

            # Audit log
            OperateLog.objects.create(
                resource_type='Investigation',
                resource=str(investigation_id),
                action='reopen',
                user=reopened_by.username,
                remote_addr='',
                is_success=True,
                detail=f'Investigation {investigation.case_number} reopened. Reason: {reason}'
            )

            logger.info(
                f"Investigation {investigation.case_number} reopened by {reopened_by.username}"
            )

            return {
                'success': True,
                'investigation': investigation.case_number
            }

        except Investigation.DoesNotExist:
            logger.error(f"Investigation {investigation_id} not found")
            return {
                'success': False,
                'error': 'Investigation not found'
            }
        except Exception as e:
            logger.error(f"Failed to reopen investigation: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }
