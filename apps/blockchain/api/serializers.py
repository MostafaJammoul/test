# -*- coding: utf-8 -*-
#
"""
Blockchain API Serializers
"""
from rest_framework import serializers
from django.utils import timezone
from users.models import User
from ..models import (
    Investigation, Evidence, BlockchainTransaction, GUIDMapping,
    Tag, InvestigationTag, InvestigationNote, InvestigationActivity
)


class InvestigationSerializer(serializers.ModelSerializer):
    """
    Investigation serializer
    """
    created_by_display = serializers.CharField(source='created_by.username', read_only=True)
    archived_by_display = serializers.CharField(source='archived_by.username', read_only=True)
    evidence_count = serializers.SerializerMethodField()
    # Read-only fields for displaying assigned users
    assigned_investigator_ids = serializers.PrimaryKeyRelatedField(
        source='assigned_investigators', many=True, read_only=True
    )
    assigned_auditor_ids = serializers.PrimaryKeyRelatedField(
        source='assigned_auditors', many=True, read_only=True
    )
    # Writable fields for assigning users (accepts list of user IDs)
    assigned_investigators = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(), many=True, required=False, write_only=True
    )
    assigned_auditors = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(), many=True, required=False, write_only=True
    )

    class Meta:
        model = Investigation
        fields = [
            'id', 'case_number', 'title', 'description', 'status',
            'created_by', 'created_by_display', 'created_at',
            'archived_by', 'archived_by_display', 'archived_at',
            'reopened_by', 'reopened_at', 'evidence_count',
            'assigned_investigator_ids', 'assigned_auditor_ids',
            'assigned_investigators', 'assigned_auditors'
        ]
        read_only_fields = ['id', 'created_by', 'created_at', 'archived_by',
                           'archived_at', 'reopened_by', 'reopened_at']

    def get_evidence_count(self, obj):
        return obj.evidence.count()

    def create(self, validated_data):
        """Handle M2M fields on create"""
        investigators = validated_data.pop('assigned_investigators', [])
        auditors = validated_data.pop('assigned_auditors', [])

        investigation = super().create(validated_data)

        if investigators:
            investigation.assigned_investigators.set(investigators)
        if auditors:
            investigation.assigned_auditors.set(auditors)

        return investigation

    def update(self, instance, validated_data):
        """Handle M2M fields on update"""
        investigators = validated_data.pop('assigned_investigators', None)
        auditors = validated_data.pop('assigned_auditors', None)

        instance = super().update(instance, validated_data)

        if investigators is not None:
            instance.assigned_investigators.set(investigators)
        if auditors is not None:
            instance.assigned_auditors.set(auditors)

        return instance


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
            'title', 'file_name', 'file_size', 'mime_type',
            'file_hash_sha256', 'ipfs_cid',
            'description', 'uploaded_by', 'uploaded_by_display',
            'hot_chain_tx_hash', 'cold_chain_tx_hash', 'is_archived',
            'uploaded_at'
        ]
        read_only_fields = ['id', 'file_hash_sha256', 'ipfs_cid',
                           'uploaded_by', 'uploaded_at']

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
            'id', 'investigation', 'transaction_hash', 'chain_type', 'evidence_hash',
            'ipfs_cid', 'user', 'user_display', 'user_guid', 'is_anonymous',
            'verified', 'metadata', 'timestamp'
        ]
        read_only_fields = ['id', 'timestamp']

    def get_is_anonymous(self, obj):
        return obj.user_guid is not None


class TagSerializer(serializers.ModelSerializer):
    """
    Tag serializer (admin-created only)
    """
    created_by_display = serializers.CharField(source='created_by.username', read_only=True)
    tagged_count = serializers.SerializerMethodField()

    class Meta:
        model = Tag
        fields = [
            'id', 'name', 'category', 'color', 'description',
            'created_by', 'created_by_display', 'created_at', 'tagged_count'
        ]
        read_only_fields = ['id', 'created_by', 'created_at']

    def get_tagged_count(self, obj):
        """Count how many investigations use this tag"""
        return obj.tagged_investigations.count()


class InvestigationTagSerializer(serializers.ModelSerializer):
    """
    Investigation-Tag relationship serializer
    Enforces max 3 tags per investigation
    """
    tag_name = serializers.CharField(source='tag.name', read_only=True)
    tag_color = serializers.CharField(source='tag.color', read_only=True)
    tag_category = serializers.CharField(source='tag.category', read_only=True)
    added_by_display = serializers.CharField(source='added_by.username', read_only=True)

    class Meta:
        model = InvestigationTag
        fields = [
            'id', 'investigation', 'tag', 'tag_name', 'tag_color', 'tag_category',
            'added_by', 'added_by_display', 'added_at'
        ]
        read_only_fields = ['id', 'added_by', 'added_at']

    def validate(self, data):
        """Enforce max 3 tags per investigation"""
        investigation = data.get('investigation')
        tag = data.get('tag')

        # Check if tag is already assigned
        if InvestigationTag.objects.filter(investigation=investigation, tag=tag).exists():
            raise serializers.ValidationError("This tag is already assigned to the investigation.")

        # Check max 3 tags limit
        current_tag_count = InvestigationTag.objects.filter(investigation=investigation).count()
        if current_tag_count >= 3:
            raise serializers.ValidationError(
                "Maximum 3 tags allowed per investigation. Remove an existing tag first."
            )

        return data


class InvestigationNoteSerializer(serializers.ModelSerializer):
    """
    Investigation note serializer (blockchain-logged)
    """
    created_by_display = serializers.CharField(source='created_by.username', read_only=True)
    blockchain_tx_hash = serializers.CharField(source='blockchain_tx.transaction_hash', read_only=True, allow_null=True)
    is_blockchain_verified = serializers.SerializerMethodField()

    class Meta:
        model = InvestigationNote
        fields = [
            'id', 'investigation', 'content', 'note_hash',
            'created_by', 'created_by_display', 'created_at',
            'blockchain_tx', 'blockchain_tx_hash', 'is_blockchain_verified'
        ]
        read_only_fields = ['id', 'note_hash', 'created_by', 'created_at', 'blockchain_tx']

    def get_is_blockchain_verified(self, obj):
        """Check if note has been logged to blockchain"""
        return obj.blockchain_tx is not None


class InvestigationActivitySerializer(serializers.ModelSerializer):
    """
    Investigation activity serializer (24-hour tracking)
    """
    performed_by_display = serializers.CharField(source='performed_by.username', read_only=True)
    is_recent = serializers.BooleanField(read_only=True)
    viewed_by_usernames = serializers.SerializerMethodField()

    class Meta:
        model = InvestigationActivity
        fields = [
            'id', 'investigation', 'activity_type', 'description',
            'performed_by', 'performed_by_display', 'timestamp',
            'is_recent', 'viewed_by', 'viewed_by_usernames'
        ]
        read_only_fields = ['id', 'performed_by', 'timestamp']

    def get_viewed_by_usernames(self, obj):
        """Get list of usernames who have viewed this activity"""
        return list(obj.viewed_by.values_list('username', flat=True))


class InvestigationDetailSerializer(serializers.ModelSerializer):
    """
    Investigation detail serializer with nested evidence, notes, transactions, activities
    Used for retrieve (GET detail) views to provide all related data
    """
    created_by_display = serializers.CharField(source='created_by.username', read_only=True)
    archived_by_display = serializers.CharField(source='archived_by.username', read_only=True, allow_null=True)
    evidence_count = serializers.SerializerMethodField()
    # Nested related data
    evidence = EvidenceSerializer(many=True, read_only=True)
    notes = InvestigationNoteSerializer(many=True, read_only=True)
    blockchain_transactions = BlockchainTransactionSerializer(source='transactions', many=True, read_only=True)
    activities = InvestigationActivitySerializer(many=True, read_only=True)
    # Read-only fields for displaying assigned users
    assigned_investigator_ids = serializers.PrimaryKeyRelatedField(
        source='assigned_investigators', many=True, read_only=True
    )
    assigned_auditor_ids = serializers.PrimaryKeyRelatedField(
        source='assigned_auditors', many=True, read_only=True
    )

    class Meta:
        model = Investigation
        fields = [
            'id', 'case_number', 'title', 'description', 'status',
            'created_by', 'created_by_display', 'created_at',
            'archived_by', 'archived_by_display', 'archived_at',
            'reopened_by', 'reopened_at', 'evidence_count',
            'assigned_investigator_ids', 'assigned_auditor_ids',
            # Nested data
            'evidence', 'notes', 'blockchain_transactions', 'activities'
        ]
        read_only_fields = ['id', 'created_by', 'created_at', 'archived_by',
                           'archived_at', 'reopened_by', 'reopened_at']

    def get_evidence_count(self, obj):
        return obj.evidence.count()
