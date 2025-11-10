#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
mTLS (Mutual TLS) Authentication Backend

This backend authenticates users based on client SSL certificates presented
during the TLS handshake. Nginx extracts certificate information and passes
it to Django via HTTP headers.

Flow:
1. User's browser sends certificate to nginx
2. nginx verifies certificate against Internal CA
3. nginx passes certificate DN via X-SSL-Client-DN header
4. This backend maps certificate DN to User in database
5. User is authenticated without password

Used with: PKI app, nginx mTLS configuration
"""

from django.contrib.auth import get_user_model
from django.contrib.auth.backends import BaseBackend

from common.utils import get_logger
from .base import JMSBaseAuthBackend

logger = get_logger(__file__)
UserModel = get_user_model()


class MTLSAuthBackend(JMSBaseAuthBackend, BaseBackend):
    """
    Authenticate users via client SSL certificates (mTLS)

    Configuration:
    - nginx must pass X-SSL-Client-DN header with certificate Subject DN
    - nginx must pass X-SSL-Client-Verify header with verification status
    - User must have a certificate in pki_certificate table
    """

    @staticmethod
    def is_enabled():
        """Check if mTLS authentication is enabled"""
        from django.conf import settings
        return getattr(settings, 'MTLS_ENABLED', False)

    def authenticate(self, request, **kwargs):
        """
        Authenticate user based on client SSL certificate

        Args:
            request: HttpRequest object with nginx headers

        Returns:
            User object if authenticated, None otherwise
        """
        if not self.is_enabled():
            return None

        if request is None:
            logger.debug("mTLS: No request object provided")
            return None

        # Get certificate info from nginx headers
        client_verify = request.META.get('HTTP_X_SSL_CLIENT_VERIFY', '')
        client_dn = request.META.get('HTTP_X_SSL_CLIENT_DN', '')
        client_cert_pem = request.META.get('HTTP_X_SSL_CLIENT_CERT', '')

        logger.debug(f"mTLS: client_verify={client_verify}, client_dn={client_dn}")

        # Check if nginx verified the certificate
        if client_verify != 'SUCCESS':
            logger.warning(f"mTLS: Client certificate verification failed: {client_verify}")
            return None

        if not client_dn:
            logger.warning("mTLS: No client DN provided in headers")
            return None

        # Look up certificate in database
        try:
            from pki.models import Certificate

            # Find certificate by subject DN
            cert = Certificate.objects.filter(
                subject_dn=client_dn,
                certificate_type='user',
                is_revoked=False
            ).select_related('user').first()

            if not cert:
                logger.warning(f"mTLS: No valid certificate found for DN: {client_dn}")
                return None

            # Check certificate expiration
            from django.utils import timezone
            now = timezone.now()

            if cert.not_before > now:
                logger.warning(f"mTLS: Certificate not yet valid for user {cert.user.username}")
                return None

            if cert.not_after < now:
                logger.warning(f"mTLS: Certificate expired for user {cert.user.username}")
                return None

            # ==================================================================
            # CERTIFICATE HASH VERIFICATION (PREVENT REISSUANCE ATTACKS)
            # ==================================================================
            # Verify certificate hash to prevent reissuance attacks
            # (Admin reissuing certificate with same DN but different key)
            if client_cert_pem and hasattr(cert, 'certificate_hash'):
                import hashlib
                import re

                # Clean PEM format (remove headers/whitespace for consistent hashing)
                cert_clean = re.sub(r'-----[^-]+-----', '', client_cert_pem)
                cert_clean = cert_clean.replace('\n', '').replace(' ', '')

                # Calculate SHA-256 hash
                calculated_hash = hashlib.sha256(cert_clean.encode()).hexdigest()

                # Compare with stored hash
                if cert.certificate_hash and cert.certificate_hash != calculated_hash:
                    logger.error(
                        f"mTLS: Certificate hash mismatch for user {cert.user.username}! "
                        f"Expected: {cert.certificate_hash[:16]}..., "
                        f"Got: {calculated_hash[:16]}... "
                        f"Possible reissuance attack or tampered certificate."
                    )
                    return None

                logger.debug(f"mTLS: Certificate hash verified for {cert.user.username}")
            # ==================================================================

            # Get the user
            user = cert.user

            if not self.user_can_authenticate(user):
                logger.warning(f"mTLS: User {user.username} cannot authenticate (inactive/invalid)")
                return None

            if not self.user_allow_authenticate(user):
                logger.warning(f"mTLS: User {user.username} not allowed to use mTLS backend")
                return None

            logger.info(f"mTLS: Successfully authenticated user {user.username} via certificate")

            # Store certificate DN in session for audit logging
            if hasattr(request, 'session'):
                request.session['mtls_cert_dn'] = client_dn
                request.session['mtls_cert_serial'] = cert.serial_number

            # ==================================================================
            # MFA ENFORCEMENT (BLOCKCHAIN SECURITY HARDENING)
            # ==================================================================
            # Check if user requires MFA (configured per user or global setting)
            from django.conf import settings

            # Check global MFA requirement
            mtls_require_mfa = getattr(settings, 'MTLS_REQUIRE_MFA', True)

            # Check user-level MFA setting
            user_mfa_enabled = getattr(user, 'mfa_level', 0) > 0

            if mtls_require_mfa or user_mfa_enabled:
                # Check if MFA already verified in this session
                mfa_session_key = f'mtls_mfa_verified_{user.id}'
                mfa_verified = request.session.get(mfa_session_key, False)

                if not mfa_verified:
                    logger.info(f"mTLS: User {user.username} requires MFA verification")
                    # Store pending user ID for MFA challenge
                    request.session['mtls_pending_user_id'] = user.id
                    request.session['mtls_mfa_required'] = True
                    # Return None to trigger MFA challenge
                    # Frontend will detect mtls_mfa_required and redirect to MFA page
                    return None
            # ==================================================================

            return user

        except Exception as e:
            logger.error(f"mTLS: Error during authentication: {e}", exc_info=True)
            return None

    def get_user(self, user_id):
        """
        Get user by ID (required by Django authentication backend)
        """
        try:
            user = UserModel.objects.get(pk=user_id)
            if self.user_can_authenticate(user):
                return user
        except UserModel.DoesNotExist:
            return None
        return None
