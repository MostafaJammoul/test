# -*- coding: utf-8 -*-
#
import uuid
from django.db import models
from django.utils.translation import gettext_lazy as _
from django.utils import timezone

from common.db.fields import EncryptTextField
from users.models import User


class CertificateAuthority(models.Model):
    """Internal Certificate Authority for issuing client certificates"""

    id = models.UUIDField(default=uuid.uuid4, primary_key=True)
    name = models.CharField(max_length=128, unique=True, verbose_name=_("CA Name"))
    certificate = EncryptTextField(verbose_name=_("CA Certificate PEM"))
    private_key = EncryptTextField(verbose_name=_("CA Private Key PEM"))
    serial_number = models.BigIntegerField(default=1, verbose_name=_("Next Serial Number"))
    is_active = models.BooleanField(default=True, verbose_name=_("Is Active"))
    created_at = models.DateTimeField(auto_now_add=True, verbose_name=_("Created At"))
    valid_from = models.DateTimeField(verbose_name=_("Valid From"))
    valid_until = models.DateTimeField(verbose_name=_("Valid Until"))

    class Meta:
        db_table = 'pki_certificate_authority'
        verbose_name = _("Certificate Authority")
        verbose_name_plural = _("Certificate Authorities")
        ordering = ['-created_at']

    def __str__(self):
        return self.name


class Certificate(models.Model):
    """Client certificates for mTLS authentication"""

    CERT_TYPE_CHOICES = (
        ('user', _('User Certificate')),
        ('service', _('Service Certificate')),
    )

    id = models.UUIDField(default=uuid.uuid4, primary_key=True)
    ca = models.ForeignKey(
        CertificateAuthority,
        on_delete=models.CASCADE,
        related_name='certificates',
        verbose_name=_("Certificate Authority")
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='certificates',
        verbose_name=_("User")
    )
    cert_type = models.CharField(
        max_length=10,
        choices=CERT_TYPE_CHOICES,
        default='user',
        verbose_name=_("Certificate Type")
    )
    serial_number = models.CharField(
        max_length=128,
        unique=True,
        db_index=True,
        verbose_name=_("Serial Number")
    )
    certificate = EncryptTextField(verbose_name=_("Certificate PEM"))
    private_key = EncryptTextField(
        null=True,
        blank=True,
        verbose_name=_("Private Key PEM")
    )
    subject_dn = models.CharField(
        max_length=512,
        verbose_name=_("Subject Distinguished Name")
    )
    issuer_dn = models.CharField(
        max_length=512,
        verbose_name=_("Issuer Distinguished Name")
    )
    not_before = models.DateTimeField(verbose_name=_("Not Before"))
    not_after = models.DateTimeField(verbose_name=_("Not After"))
    revoked = models.BooleanField(default=False, verbose_name=_("Revoked"))
    revocation_date = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name=_("Revocation Date")
    )
    revocation_reason = models.CharField(
        max_length=256,
        null=True,
        blank=True,
        verbose_name=_("Revocation Reason")
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name=_("Created At"))

    class Meta:
        db_table = 'pki_certificate'
        verbose_name = _("Certificate")
        verbose_name_plural = _("Certificates")
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['serial_number']),
            models.Index(fields=['user', 'revoked']),
            models.Index(fields=['not_after']),
        ]

    def __str__(self):
        return f"{self.subject_dn} ({self.serial_number})"

    def is_valid(self):
        """Check if certificate is currently valid"""
        now = timezone.now()
        return (
            not self.revoked and
            self.not_before <= now <= self.not_after
        )

    def revoke(self, reason=""):
        """Revoke this certificate"""
        self.revoked = True
        self.revocation_date = timezone.now()
        self.revocation_reason = reason
        self.save(update_fields=['revoked', 'revocation_date', 'revocation_reason'])


class CertificateRevocationList(models.Model):
    """Certificate Revocation List for checking revoked certificates"""

    id = models.UUIDField(default=uuid.uuid4, primary_key=True)
    ca = models.ForeignKey(
        CertificateAuthority,
        on_delete=models.CASCADE,
        related_name='crls',
        verbose_name=_("Certificate Authority")
    )
    crl_pem = models.TextField(verbose_name=_("CRL PEM"))
    this_update = models.DateTimeField(verbose_name=_("This Update"))
    next_update = models.DateTimeField(verbose_name=_("Next Update"))
    created_at = models.DateTimeField(auto_now_add=True, verbose_name=_("Created At"))

    class Meta:
        db_table = 'pki_certificate_revocation_list'
        verbose_name = _("Certificate Revocation List")
        verbose_name_plural = _("Certificate Revocation Lists")
        ordering = ['-created_at']

    def __str__(self):
        return f"CRL for {self.ca.name} - {self.this_update}"
