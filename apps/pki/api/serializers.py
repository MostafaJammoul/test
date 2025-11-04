# -*- coding: utf-8 -*-
#
"""
PKI API Serializers
"""
from rest_framework import serializers
from ..models import CertificateAuthority, UserCertificate, CertificateRevocation


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


class UserCertificateSerializer(serializers.ModelSerializer):
    """
    User certificate serializer
    """
    user_display = serializers.CharField(source='user.username', read_only=True)
    ca_name = serializers.CharField(source='ca.name', read_only=True)
    issued_by_display = serializers.CharField(source='issued_by.username', read_only=True)
    days_until_expiry = serializers.SerializerMethodField()
    is_expired = serializers.SerializerMethodField()

    class Meta:
        model = UserCertificate
        fields = [
            'id', 'ca', 'ca_name', 'user', 'user_display',
            'serial_number', 'subject_dn', 'status',
            'not_valid_before', 'not_valid_after',
            'days_until_expiry', 'is_expired',
            'issued_by', 'issued_by_display', 'created_at'
        ]
        read_only_fields = [
            'id', 'serial_number', 'subject_dn',
            'not_valid_before', 'not_valid_after', 'created_at'
        ]

    def get_days_until_expiry(self, obj):
        from django.utils import timezone
        if obj.not_valid_after:
            delta = obj.not_valid_after - timezone.now()
            return max(0, delta.days)
        return None

    def get_is_expired(self, obj):
        from django.utils import timezone
        if obj.not_valid_after:
            return timezone.now() > obj.not_valid_after
        return False


class CertificateRevocationSerializer(serializers.ModelSerializer):
    """
    Certificate revocation serializer
    """
    certificate_serial = serializers.CharField(source='certificate.serial_number', read_only=True)
    user_display = serializers.CharField(source='certificate.user.username', read_only=True)
    revoked_by_display = serializers.CharField(source='revoked_by.username', read_only=True)

    class Meta:
        model = CertificateRevocation
        fields = [
            'id', 'certificate', 'certificate_serial', 'user_display',
            'reason', 'revoked_by', 'revoked_by_display', 'revoked_at'
        ]
        read_only_fields = ['id', 'revoked_at']
