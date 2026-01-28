# -*- coding: utf-8 -*-
#
"""
Signal Handlers for Blockchain Operations
Automatically logs blockchain operations to audit trail
"""
from django.db.models.signals import post_save, pre_delete, post_delete
from django.dispatch import receiver
from audits.models import OperateLog
from .models import (
    BlockchainTransaction, Evidence, Investigation,
    InvestigationNote, InvestigationTag, InvestigationActivity
)


@receiver(post_save, sender=BlockchainTransaction)
def log_blockchain_transaction(sender, instance, created, **kwargs):
    """Log blockchain transaction to audit trail"""
    if created:
        user_identifier = instance.user.username if instance.user else instance.user_guid

        OperateLog.objects.create(
            resource_type='BlockchainTransaction',
            resource=str(instance.id),
            action='append' if instance.chain_type == 'hot' else 'archive',
            user=user_identifier,
            remote_addr='',
            diff={
                'success': True,
                'detail': f'{instance.chain_type.upper()} chain transaction: {instance.transaction_hash}'
            }
        )


@receiver(post_save, sender=Evidence)
def log_evidence_upload(sender, instance, created, **kwargs):
    """Log evidence upload to audit trail"""
    if created:
        user_identifier = instance.uploaded_by.username if instance.uploaded_by else instance.uploaded_by_guid

        OperateLog.objects.create(
            resource_type='Evidence',
            resource=str(instance.id),
            action='upload',
            user=user_identifier,
            remote_addr='',
            diff={
                'success': True,
                'detail': f'Evidence uploaded: {instance.file_name} (SHA-256: {instance.file_hash_sha256[:16]}..., IPFS: {instance.ipfs_cid})'
            }
        )


@receiver(post_save, sender=Investigation)
def log_investigation_status_change(sender, instance, created, **kwargs):
    """Log investigation status changes"""
    if not created:
        # Only log status changes after creation
        # Handle update_fields being None (when save() called without it)
        update_fields = kwargs.get('update_fields') or []
        if 'status' in update_fields:
            action = 'create' if instance.status == 'active' else 'archive'
            user = instance.archived_by if instance.status == 'archived' else instance.reopened_by

            if user:
                OperateLog.objects.create(
                    resource_type='Investigation',
                    resource=str(instance.id),
                    action=action,
                    user=user.username,
                    remote_addr='',
                    diff={
                        'success': True,
                        'detail': f'Investigation {instance.case_number} status changed to {instance.status}'
                    }
                )


# ==============================================================================
# UI ENHANCEMENT SIGNALS - AUTOMATIC ACTIVITY TRACKING
# ==============================================================================

@receiver(post_save, sender=Evidence)
def track_evidence_added(sender, instance, created, **kwargs):
    """Automatically create activity when evidence is added"""
    if created:
        InvestigationActivity.objects.create(
            investigation=instance.investigation,
            activity_type='evidence_added',
            description=f'Evidence file "{instance.file_name}" was added to the investigation',
            performed_by=instance.uploaded_by
        )


@receiver(post_save, sender=InvestigationNote)
def track_note_added(sender, instance, created, **kwargs):
    """Automatically create activity when note is added"""
    if created:
        InvestigationActivity.objects.create(
            investigation=instance.investigation,
            activity_type='note_added',
            description=f'Investigation note was added by {instance.created_by.username if instance.created_by else "Unknown"}',
            performed_by=instance.created_by
        )


@receiver(post_save, sender=InvestigationTag)
def track_tag_added(sender, instance, created, **kwargs):
    """Automatically create activity when tag is assigned"""
    if created:
        InvestigationActivity.objects.create(
            investigation=instance.investigation,
            activity_type='tag_changed',
            description=f'Tag "{instance.tag.name}" was added to the investigation',
            performed_by=instance.added_by
        )


@receiver(post_delete, sender=InvestigationTag)
def track_tag_removed(sender, instance, **kwargs):
    """Automatically create activity when tag is removed"""
    InvestigationActivity.objects.create(
        investigation=instance.investigation,
        activity_type='tag_changed',
        description=f'Tag "{instance.tag.name}" was removed from the investigation',
        performed_by=None  # No user context in post_delete, could store in request context
    )


@receiver(post_save, sender=Investigation)
def track_investigation_status_change_activity(sender, instance, created, **kwargs):
    """Track investigation status changes as activity"""
    # Handle update_fields being None (when save() called without it)
    update_fields = kwargs.get('update_fields') or []
    if not created and 'status' in update_fields:
        user = instance.archived_by if instance.status == 'archived' else instance.reopened_by
        action = 'archived' if instance.status == 'archived' else 'reopened'

        InvestigationActivity.objects.create(
            investigation=instance,
            activity_type='status_changed',
            description=f'Investigation was {action}',
            performed_by=user
        )
