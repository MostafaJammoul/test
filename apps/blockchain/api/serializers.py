# -*- coding: utf-8 -*-
#
"""
Blockchain API Serializers
"""
from rest_framework import serializers
from django.utils import timezone
from ..models import Investigation, Evidence, BlockchainTransaction, GUIDMapping


class InvestigationSerializer(serializers.ModelSerializer):
    """
    Investigation serializer
    """
    created_by_display = serializers.CharField(source='created_by.username', read_only=True)
    archived_by_display = serializers.CharField(source='archived_by.username', read_only=True)
    evidence_count = serializers.SerializerMethodField()

    class Meta:
        model = Investigation
        fields = [
            'id', 'case_number', 'title', 'description', 'status',
            'created_by', 'created_by_display', 'created_at',
            'archived_by', 'archived_by_display', 'archived_at',
            'reopened_by', 'reopened_at', 'evidence_count'
        ]
        read_only_fields = ['id', 'created_by', 'created_at', 'archived_by',
                           'archived_at', 'reopened_by', 'reopened_at']

    def get_evidence_count(self, obj):
        return obj.evidence_set.count()


class EvidenceSerializer(serializers.ModelSerializer):
    """
    Evidence serializer
    """
    uploaded_by_display = serializers.CharField(source='uploaded_by.username', read_only=True)
    investigation_case_number = serializers.CharField(source='investigation.case_number', read_only=True)
    hot_chain_tx_hash = serializers.CharField(source='hot_chain_tx.transaction_hash', read_only=True)
    cold_chain_tx_hash = serializers.CharField(source='cold_chain_tx.transaction_hash', read_only=True, allow_null=True)
    is_archived = serializers.SerializerMethodField()

    class Meta:
        model = Evidence
        fields = [
            'id', 'investigation', 'investigation_case_number',
            'file_name', 'file_size', 'file_hash_sha256', 'ipfs_cid',
            'description', 'uploaded_by', 'uploaded_by_display',
            'hot_chain_tx_hash', 'cold_chain_tx_hash', 'is_archived',
            'created_at'
        ]
        read_only_fields = ['id', 'file_hash_sha256', 'ipfs_cid',
                           'uploaded_by', 'created_at']

    def get_is_archived(self, obj):
        return obj.cold_chain_tx is not None


class BlockchainTransactionSerializer(serializers.ModelSerializer):
    """
    Blockchain transaction serializer
    """
    user_display = serializers.CharField(source='user.username', read_only=True)
    is_anonymous = serializers.SerializerMethodField()

    class Meta:
        model = BlockchainTransaction
        fields = [
            'id', 'transaction_hash', 'chain_type', 'evidence_hash',
            'ipfs_cid', 'user', 'user_display', 'user_guid', 'is_anonymous',
            'merkle_proof', 'metadata', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']

    def get_is_anonymous(self, obj):
        return obj.user_guid is not None
