# -*- coding: utf-8 -*-
#
"""
PKI API Serializers
"""
from rest_framework import serializers
from ..models import CertificateAuthority, Certificate, CertificateRevocation


class CertificateAuthoritySerializer(serializers.ModelSerializer):
    """
    Certificate Authority serializer
    """
    is_expired = serializers.SerializerMethodField()

    class Meta:
        model = CertificateAuthority
        fields = [
            'id', 'name', 'serial_number', 'is_active',
            'created_at', 'is_expired'
        ]
        read_only_fields = ['id', 'serial_number', 'created_at']

    def get_is_expired(self, obj):
        # CAs typically have long validity (10-20 years)
        # Add expiry check if you store not_valid_after
        return False


class CertificateSerializer(serializers.ModelSerializer):
    """
    Certificate serializer for user/service certificates
    """
    user_display = serializers.CharField(source='user.username', read_only=True)
    ca_name = serializers.CharField(source='ca.name', read_only=True)
    days_until_expiry = serializers.SerializerMethodField()
    is_expired = serializers.SerializerMethodField()
    is_valid = serializers.BooleanField(read_only=True)

    class Meta:
        model = Certificate
        fields = [
            'id', 'ca', 'ca_name', 'user', 'user_display',
            'cert_type', 'serial_number', 'subject_dn', 'issuer_dn',
            'not_before', 'not_after', 'days_until_expiry', 'is_expired',
            'revoked', 'revocation_date', 'revocation_reason',
            'created_at', 'is_valid'
        ]
        read_only_fields = [
            'id', 'serial_number', 'subject_dn', 'issuer_dn',
            'not_before', 'not_after', 'created_at', 'is_valid'
        ]

    def get_days_until_expiry(self, obj):
        from django.utils import timezone
        if obj.not_after:
            delta = obj.not_after - timezone.now()
            return max(0, delta.days)
        return None

    def get_is_expired(self, obj):
        from django.utils import timezone
        if obj.not_after:
            return timezone.now() > obj.not_after
        return False


# Alias for compatibility
UserCertificateSerializer = CertificateSerializer


class CertificateRevocationSerializer(serializers.ModelSerializer):
    """Certificate revocation history serializer"""
    certificate_serial = serializers.CharField(source='certificate.serial_number', read_only=True)
    revoked_by_username = serializers.CharField(source='revoked_by.username', read_only=True)

    class Meta:
        model = CertificateRevocation
        fields = [
            'id', 'certificate', 'certificate_serial', 'reason',
            'revoked_by', 'revoked_by_username', 'revoked_at', 'created_at'
        ]
        read_only_fields = ['id', 'revoked_by', 'revoked_at', 'created_at']

