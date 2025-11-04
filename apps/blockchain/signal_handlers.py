# -*- coding: utf-8 -*-
#
"""
Signal Handlers for Blockchain Operations
Automatically logs blockchain operations to audit trail
"""
from django.db.models.signals import post_save, pre_delete
from django.dispatch import receiver
from audits.models import OperateLog
from .models import BlockchainTransaction, Evidence, Investigation


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
            is_success=True,
            detail=f'{instance.chain_type.upper()} chain transaction: {instance.transaction_hash}'
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
            is_success=True,
            detail=f'Evidence uploaded: {instance.file_name} (SHA-256: {instance.file_hash_sha256[:16]}..., IPFS: {instance.ipfs_cid})'
        )


@receiver(post_save, sender=Investigation)
def log_investigation_status_change(sender, instance, created, **kwargs):
    """Log investigation status changes"""
    if not created:
        # Only log status changes after creation
        if 'status' in kwargs.get('update_fields', []):
            action = 'create' if instance.status == 'active' else 'archive'
            user = instance.archived_by if instance.status == 'archived' else instance.reopened_by

            if user:
                OperateLog.objects.create(
                    resource_type='Investigation',
                    resource=str(instance.id),
                    action=action,
                    user=user.username,
                    remote_addr='',
                    is_success=True,
                    detail=f'Investigation {instance.case_number} status changed to {instance.status}'
                )
