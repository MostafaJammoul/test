# -*- coding: utf-8 -*-
#
import uuid
import hashlib
from django.db import models
from django.utils.translation import gettext_lazy as _
from django.utils import timezone

from common.db.fields import EncryptCharField
from users.models import User
from orgs.mixins.models import JMSOrgBaseModel


class Investigation(JMSOrgBaseModel):
    """Investigation/Case container for evidence"""

    STATUS_CHOICES = (
        ('active', _('Active')),
        ('archived', _('Archived')),
    )

    id = models.UUIDField(default=uuid.uuid4, primary_key=True)
    case_number = models.CharField(max_length=128, unique=True, db_index=True, verbose_name=_("Case Number"))
    title = models.CharField(max_length=512, verbose_name=_("Title"))
    description = models.TextField(verbose_name=_("Description"))
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='active', verbose_name=_("Status"))
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='investigations_created', verbose_name=_("Created By"))
    archived_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='investigations_archived', verbose_name=_("Archived By"))
    reopened_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='investigations_reopened', verbose_name=_("Reopened By"))
    created_at = models.DateTimeField(auto_now_add=True, verbose_name=_("Created At"))
    archived_at = models.DateTimeField(null=True, blank=True, verbose_name=_("Archived At"))
    reopened_at = models.DateTimeField(null=True, blank=True, verbose_name=_("Reopened At"))
    reopen_reason = models.TextField(null=True, blank=True, verbose_name=_("Reopen Reason"))

    class Meta:
        db_table = 'blockchain_investigation'
        verbose_name = _("Investigation")
        verbose_name_plural = _("Investigations")
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.case_number} - {self.title}"


class BlockchainTransaction(JMSOrgBaseModel):
    """Record of blockchain transactions"""

    CHAIN_TYPE_CHOICES = (
        ('hot', _('Hot Chain')),
        ('cold', _('Cold Chain')),
    )

    id = models.UUIDField(default=uuid.uuid4, primary_key=True)
    investigation = models.ForeignKey(Investigation, on_delete=models.CASCADE, related_name='transactions', verbose_name=_("Investigation"))
    transaction_hash = models.CharField(max_length=256, unique=True, db_index=True, verbose_name=_("Transaction Hash"))
    chain_type = models.CharField(max_length=4, choices=CHAIN_TYPE_CHOICES, verbose_name=_("Chain Type"))
    block_number = models.BigIntegerField(null=True, blank=True, verbose_name=_("Block Number"))
    evidence_hash = models.CharField(max_length=256, verbose_name=_("Evidence Hash (SHA-256)"))
    ipfs_cid = models.CharField(max_length=128, null=True, blank=True, db_index=True, verbose_name=_("IPFS CID"))
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='blockchain_transactions', verbose_name=_("User"))
    user_guid = EncryptCharField(max_length=256, null=True, blank=True, verbose_name=_("User GUID (if anonymous)"))
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True, verbose_name=_("Timestamp"))
    merkle_root = models.CharField(max_length=256, verbose_name=_("Merkle Root"))
    metadata = models.JSONField(default=dict, verbose_name=_("Metadata"))
    verified = models.BooleanField(default=False, verbose_name=_("Verified"))
    verification_date = models.DateTimeField(null=True, blank=True, verbose_name=_("Verification Date"))

    class Meta:
        db_table = 'blockchain_transaction'
        verbose_name = _("Blockchain Transaction")
        verbose_name_plural = _("Blockchain Transactions")
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['transaction_hash']),
            models.Index(fields=['chain_type', 'timestamp']),
            models.Index(fields=['investigation', 'chain_type']),
            models.Index(fields=['ipfs_cid']),
        ]

    def __str__(self):
        return f"{self.chain_type} - {self.transaction_hash[:16]}..."


class Evidence(JMSOrgBaseModel):
    """Evidence file metadata"""

    id = models.UUIDField(default=uuid.uuid4, primary_key=True)
    investigation = models.ForeignKey(Investigation, on_delete=models.CASCADE, related_name='evidence', verbose_name=_("Investigation"))
    title = models.CharField(max_length=512, verbose_name=_("Title"))
    description = models.TextField(blank=True, verbose_name=_("Description"))
    file_name = models.CharField(max_length=512, verbose_name=_("File Name"))
    file_size = models.BigIntegerField(verbose_name=_("File Size (bytes)"))
    mime_type = models.CharField(max_length=128, verbose_name=_("MIME Type"))
    file_hash_sha256 = models.CharField(max_length=64, db_index=True, verbose_name=_("SHA-256 Hash"))
    ipfs_cid = models.CharField(max_length=128, db_index=True, verbose_name=_("IPFS CID"))
    encryption_key_id = EncryptCharField(max_length=256, verbose_name=_("Encryption Key ID"))
    uploaded_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='evidence_uploaded', verbose_name=_("Uploaded By"))
    uploaded_by_guid = EncryptCharField(max_length=256, null=True, blank=True, verbose_name=_("Uploader GUID (if anonymous)"))
    uploaded_at = models.DateTimeField(auto_now_add=True, verbose_name=_("Uploaded At"))
    hot_chain_tx = models.ForeignKey(BlockchainTransaction, on_delete=models.SET_NULL, null=True, related_name='hot_evidence', verbose_name=_("Hot Chain Transaction"))
    cold_chain_tx = models.ForeignKey(BlockchainTransaction, on_delete=models.SET_NULL, null=True, blank=True, related_name='cold_evidence', verbose_name=_("Cold Chain Transaction"))
    merkle_proof = models.JSONField(default=dict, verbose_name=_("Merkle Proof"))

    class Meta:
        db_table = 'blockchain_evidence'
        verbose_name = _("Evidence")
        verbose_name_plural = _("Evidence")
        ordering = ['-uploaded_at']
        indexes = [
            models.Index(fields=['file_hash_sha256']),
            models.Index(fields=['ipfs_cid']),
            models.Index(fields=['investigation', 'uploaded_at']),
        ]

    def __str__(self):
        return f"{self.file_name} ({self.file_hash_sha256[:16]}...)"

    def calculate_hash(self, file_data):
        """Calculate SHA-256 hash of file data"""
        return hashlib.sha256(file_data).hexdigest()


class GUIDMapping(models.Model):
    """GUID to User identity mapping (internal DNS-like service)"""

    id = models.UUIDField(default=uuid.uuid4, primary_key=True)
    guid = EncryptCharField(max_length=256, unique=True, db_index=True, verbose_name=_("Anonymous GUID"))
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='guid_mapping', verbose_name=_("User"))
    created_at = models.DateTimeField(auto_now_add=True, verbose_name=_("Created At"))

    class Meta:
        db_table = 'blockchain_guid_mapping'
        verbose_name = _("GUID Mapping")
        verbose_name_plural = _("GUID Mappings")
        permissions = [
            ('resolve_guid', 'Can resolve GUID to real identity'),
        ]

    def __str__(self):
        return f"GUID: {self.guid[:16]}... → {self.user.username}"
