# -*- coding: utf-8 -*-
#
"""
PKI (Public Key Infrastructure) API Views

REST API endpoints for internal Certificate Authority management,
certificate issuance, renewal, and revocation.

CONFIGURATION REQUIRED:
    1. CA Initialization: Run `python manage.py create_internal_ca` first
    2. Certificate Storage: Ensure /etc/jumpserver/certs/ directory exists
    3. Nginx mTLS: Configure nginx to pass client certificates to backend
    4. Certificate Rotation: Set up Celery beat task for auto-renewal
"""
import logging
from datetime import datetime, timedelta
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.http import HttpResponse
from django.utils import timezone
from rest_framework import viewsets, status, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend

from common.permissions import IsValidUser
from rbac.permissions import RBACPermission
from orgs.mixins.api import OrgBulkModelViewSet
from ..models import CertificateAuthority, UserCertificate, CertificateRevocation
from ..ca_manager import CAManager
from .serializers import CertificateAuthoritySerializer, UserCertificateSerializer, CertificateRevocationSerializer

logger = logging.getLogger(__name__)


# =============================================================================
# CONFIGURATION NOTES
# =============================================================================
#
# STEP 1: Initialize Internal CA
# -------------------------------
# Before using these APIs, create your internal Certificate Authority:
#
#   python manage.py create_internal_ca \
#       --name "JumpServer Internal CA" \
#       --validity-years 10 \
#       --key-size 4096
#
# This creates the root CA certificate and private key (encrypted in database)
#
#
# STEP 2: Configure Nginx for mTLS
# ---------------------------------
# Nginx must be configured to:
#   1. Require client certificates (ssl_verify_client on)
#   2. Trust your internal CA (ssl_client_certificate /path/to/ca.crt)
#   3. Pass client cert to backend via headers
#
# Example nginx.conf:
#
#   server {
#       listen 443 ssl;
#       server_name jumpserver.example.com;
#
#       # Server certificate (can be from public CA like Let's Encrypt)
#       ssl_certificate /etc/nginx/ssl/server.crt;
#       ssl_certificate_key /etc/nginx/ssl/server.key;
#
#       # Client certificate verification (uses YOUR internal CA)
#       ssl_client_certificate /etc/nginx/ssl/internal-ca.crt;
#       ssl_verify_client on;  # or 'optional' for mixed auth
#       ssl_verify_depth 2;
#
#       # Pass client cert to backend
#       location / {
#           proxy_pass http://127.0.0.1:8080;
#           proxy_set_header X-SSL-Client-Cert $ssl_client_cert;
#           proxy_set_header X-SSL-Client-DN $ssl_client_s_dn;
#           proxy_set_header X-SSL-Client-Verify $ssl_client_verify;
#       }
#   }
#
# Export your CA certificate for nginx:
#   python manage.py export_ca_cert --output /etc/nginx/ssl/internal-ca.crt
#
#
# STEP 3: Issue User Certificates
# --------------------------------
# Issue certificates to users via this API or management command:
#
#   # Via API: POST /api/v1/pki/certificates/issue/
#   # Via CLI: python manage.py issue_user_cert --username investigator1
#
# The certificate will be:
#   1. Generated (RSA 2048-bit or ECC P-256)
#   2. Signed by your internal CA
#   3. Stored in database (encrypted)
#   4. Provided as downloadable .p12 file (PKCS#12 format)
#
# Users import the .p12 file into their browser/OS:
#   - Windows: Double-click .p12 file
#   - macOS: Open Keychain Access → Import
#   - Linux: Install in browser or system cert store
#
#
# STEP 4: Certificate Renewal
# ----------------------------
# Certificates expire after 365 days (configurable). Set up auto-renewal:
#
# In settings/base.py, add to CELERY_BEAT_SCHEDULE:
#
#   CELERY_BEAT_SCHEDULE = {
#       'renew-expiring-certificates': {
#           'task': 'pki.tasks.renew_expiring_certificates',
#           'schedule': crontab(hour=2, minute=0),  # Daily at 2 AM
#       },
#   }
#
# Create pki/tasks.py:
#
#   from common.celery_decorator import register_as_period_task
#   from .ca_manager import CAManager
#
#   @register_as_period_task(crontab="0 2 * * *")
#   def renew_expiring_certificates(self):
#       \"\"\"Renew certificates expiring in 30 days\"\"\"
#       ca_manager = CAManager()
#       result = ca_manager.renew_expiring_certificates(days_before=30)
#       return result
#
#
# STEP 5: Certificate Revocation
# -------------------------------
# If a certificate is compromised or user leaves:
#
#   # Via API: POST /api/v1/pki/certificates/{id}/revoke/
#   # Via CLI: python manage.py revoke_user_cert --username user1 --reason key_compromise
#
# This:
#   1. Marks certificate as revoked in database
#   2. Generates new CRL (Certificate Revocation List)
#   3. Publishes CRL to /api/v1/pki/crl/ endpoint
#
# Configure nginx to check CRL (optional but recommended):
#   ssl_crl /etc/nginx/ssl/internal-ca.crl;
#
# Update CRL periodically:
#   python manage.py export_crl --output /etc/nginx/ssl/internal-ca.crl
#
# Or automate via Celery:
#   @register_as_period_task(crontab="0 */6 * * *")  # Every 6 hours
#   def update_crl(self):
#       os.system("python manage.py export_crl --output /etc/nginx/ssl/internal-ca.crl")
#       os.system("nginx -s reload")
#
#
# =============================================================================


class CertificateAuthorityViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Certificate Authority Information API (Read-Only)

    Endpoints:
        GET /api/v1/pki/ca/           - List CAs
        GET /api/v1/pki/ca/{id}/      - Get CA detail
        GET /api/v1/pki/ca/{id}/cert/ - Download CA certificate (PEM format)

    Permissions:
        - All authenticated users can view CA information
        - Admin only can create/modify CA (via management command)
    """
    queryset = CertificateAuthority.objects.filter(is_active=True)
    serializer_class = CertificateAuthoritySerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [filters.OrderingFilter]
    ordering = ['-created_at']

    @action(detail=True, methods=['get'])
    def cert(self, request, pk=None):
        """
        Download CA certificate in PEM format

        This certificate should be:
        1. Installed in nginx (ssl_client_certificate)
        2. Distributed to users for trust establishment
        3. Used by external systems to verify user certificates
        """
        ca = self.get_object()

        response = HttpResponse(ca.certificate, content_type='application/x-pem-file')
        response['Content-Disposition'] = f'attachment; filename="{ca.name}.crt"'

        logger.info(f"CA certificate {ca.name} downloaded by {request.user.username}")

        return response


class UserCertificateViewSet(OrgBulkModelViewSet):
    """
    User Certificate Management API

    Endpoints:
        GET    /api/v1/pki/certificates/                    - List certificates
        POST   /api/v1/pki/certificates/issue/              - Issue new certificate
        GET    /api/v1/pki/certificates/{id}/               - Get certificate detail
        GET    /api/v1/pki/certificates/{id}/download/      - Download certificate (.p12)
        POST   /api/v1/pki/certificates/{id}/revoke/        - Revoke certificate
        POST   /api/v1/pki/certificates/{id}/renew/         - Renew certificate

    Permissions:
        - Admin: Issue, revoke any certificate
        - Users: View and download their own certificates
    """
    model = UserCertificate
    serializer_class = UserCertificateSerializer
    permission_classes = [IsAuthenticated, RBACPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['user__username', 'user__name', 'subject_dn']
    filterset_fields = ['user', 'status', 'ca']
    ordering_fields = ['created_at', 'not_valid_after']

    def get_queryset(self):
        """
        Filter certificates based on user role
        - Admins see all certificates
        - Users see only their own
        """
        queryset = super().get_queryset()
        user = self.request.user

        if user.is_superuser or user.has_perm('pki.view_all_certificates'):
            return queryset

        return queryset.filter(user=user)

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def issue(self, request):
        """
        Issue a new certificate to a user

        Request payload:
            - user_id: UUID of user (if admin issuing for others)
            - validity_days: Certificate validity in days (default: 365)
            - key_algorithm: 'rsa' or 'ecc' (default: rsa)
            - key_size: 2048, 3072, or 4096 for RSA (default: 2048)
            - password: Password to protect .p12 file (optional)

        Returns:
            - certificate_id: UUID
            - subject_dn: Certificate Distinguished Name
            - serial_number: Certificate serial number
            - not_valid_before: Start date
            - not_valid_after: Expiry date
            - download_url: URL to download .p12 file

        Process:
            1. Validate user exists and can receive certificate
            2. Generate key pair (RSA 2048-bit or ECC P-256)
            3. Create CSR (Certificate Signing Request)
            4. Sign CSR with internal CA
            5. Store certificate in database (encrypted)
            6. Return certificate details + download link

        CONFIGURATION:
            - Requires active CA (check CertificateAuthority.objects.filter(is_active=True).first())
        """
        # Check permission
        if not request.user.is_superuser and not request.user.has_perm('pki.issue_certificate'):
            raise PermissionDenied("Insufficient permissions to issue certificates")

        # Get parameters
        user_id = request.data.get('user_id', str(request.user.id))
        validity_days = int(request.data.get('validity_days', 365))
        key_algorithm = request.data.get('key_algorithm', 'rsa')
        key_size = int(request.data.get('key_size', 2048))
        p12_password = request.data.get('password', '')

        # Validate parameters
        if key_algorithm not in ['rsa', 'ecc']:
            return Response(
                {'error': 'key_algorithm must be "rsa" or "ecc"'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if key_algorithm == 'rsa' and key_size not in [2048, 3072, 4096]:
            return Response(
                {'error': 'key_size must be 2048, 3072, or 4096 for RSA'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Get user
        from users.models import User
        try:
            target_user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Check if user already has valid certificate
        existing_cert = UserCertificate.objects.filter(
            user=target_user,
            status='valid',
            not_valid_after__gt=timezone.now()
        ).first()

        if existing_cert:
            return Response(
                {
                    'error': 'User already has a valid certificate',
                    'certificate_id': str(existing_cert.id),
                    'expires_at': existing_cert.not_valid_after.isoformat()
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # Get active CA
            ca = CertificateAuthority.objects.filter(is_active=True).first()
            if not ca:
                return Response(
                    {'error': 'No active Certificate Authority. Run: python manage.py create_internal_ca'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )

            # Initialize CA manager
            ca_manager = CAManager()

            # Issue certificate
            cert_data = ca_manager.issue_user_certificate(
                ca=ca,
                user=target_user,
                validity_days=validity_days,
                key_algorithm=key_algorithm,
                key_size=key_size if key_algorithm == 'rsa' else None
            )

            # Create certificate record
            user_cert = UserCertificate.objects.create(
                ca=ca,
                user=target_user,
                certificate=cert_data['certificate_pem'],
                private_key=cert_data['private_key_pem'],  # Encrypted by model
                serial_number=cert_data['serial_number'],
                subject_dn=cert_data['subject_dn'],
                not_valid_before=cert_data['not_valid_before'],
                not_valid_after=cert_data['not_valid_after'],
                status='valid',
                issued_by=request.user
            )

            logger.info(
                f"Certificate {cert_data['serial_number']} issued to {target_user.username} "
                f"by {request.user.username}"
            )

            return Response({
                'status': 'success',
                'certificate_id': str(user_cert.id),
                'serial_number': cert_data['serial_number'],
                'subject_dn': cert_data['subject_dn'],
                'not_valid_before': cert_data['not_valid_before'].isoformat(),
                'not_valid_after': cert_data['not_valid_after'].isoformat(),
                'download_url': f'/api/v1/pki/certificates/{user_cert.id}/download/'
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            logger.error(f"Failed to issue certificate: {e}", exc_info=True)
            return Response(
                {'error': f'Failed to issue certificate: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['get'], permission_classes=[IsAuthenticated])
    def download(self, request, pk=None):
        """
        Download certificate in PKCS#12 (.p12) format

        The .p12 file contains:
        - User's private key (encrypted with password)
        - User's certificate
        - CA certificate chain

        Users import this into their browser/OS for mTLS authentication.

        Query parameters:
            - password: Password to encrypt .p12 file (optional, default: empty)

        Returns:
            application/x-pkcs12 file
        """
        cert = self.get_object()

        # Check permission
        if not (request.user == cert.user or request.user.is_superuser):
            raise PermissionDenied("You can only download your own certificates")

        # Check if certificate is valid
        if cert.status != 'valid':
            return Response(
                {'error': f'Certificate is {cert.status}, cannot download'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            p12_password = request.query_params.get('password', '').encode('utf-8')

            ca_manager = CAManager()
            p12_data = ca_manager.export_pkcs12(
                certificate_pem=cert.certificate,
                private_key_pem=cert.private_key,  # Decrypted by model
                ca_cert_pem=cert.ca.certificate,
                password=p12_password
            )

            response = HttpResponse(p12_data, content_type='application/x-pkcs12')
            response['Content-Disposition'] = f'attachment; filename="{cert.user.username}.p12"'

            logger.info(f"Certificate {cert.serial_number} downloaded by {request.user.username}")

            return response

        except Exception as e:
            logger.error(f"Failed to export certificate as PKCS#12: {e}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def revoke(self, request, pk=None):
        """
        Revoke a certificate

        Request payload:
            - reason: Revocation reason (required)
                Options: 'unspecified', 'key_compromise', 'ca_compromise',
                        'affiliation_changed', 'superseded', 'cessation_of_operation'

        Process:
            1. Mark certificate as revoked
            2. Create revocation record
            3. Regenerate CRL (Certificate Revocation List)
            4. Update nginx CRL (if configured)

        After revocation:
            - User cannot authenticate with this certificate
            - Certificate appears in CRL (/api/v1/pki/crl/)
            - nginx will reject the certificate (if ssl_crl configured)
        """
        cert = self.get_object()

        # Check permission
        if not (request.user.is_superuser or request.user.has_perm('pki.revoke_certificate')):
            raise PermissionDenied("Insufficient permissions to revoke certificates")

        reason = request.data.get('reason', 'unspecified')

        valid_reasons = [
            'unspecified', 'key_compromise', 'ca_compromise',
            'affiliation_changed', 'superseded', 'cessation_of_operation'
        ]

        if reason not in valid_reasons:
            return Response(
                {'error': f'Invalid reason. Must be one of: {", ".join(valid_reasons)}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Check if already revoked
        if cert.status == 'revoked':
            return Response(
                {'error': 'Certificate already revoked'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # Revoke certificate
            cert.status = 'revoked'
            cert.save()

            # Create revocation record
            revocation = CertificateRevocation.objects.create(
                certificate=cert,
                reason=reason,
                revoked_by=request.user,
                revoked_at=timezone.now()
            )

            # TODO: Regenerate CRL and update nginx
            # ca_manager = CAManager()
            # crl_pem = ca_manager.generate_crl(cert.ca)
            # Update /etc/nginx/ssl/internal-ca.crl
            # Reload nginx

            logger.warning(
                f"Certificate {cert.serial_number} (user: {cert.user.username}) "
                f"revoked by {request.user.username}. Reason: {reason}"
            )

            return Response({
                'status': 'success',
                'message': f'Certificate revoked',
                'serial_number': cert.serial_number,
                'reason': reason,
                'revoked_at': revocation.revoked_at.isoformat()
            })

        except Exception as e:
            logger.error(f"Failed to revoke certificate {cert.serial_number}: {e}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def renew(self, request, pk=None):
        """
        Renew an expiring certificate

        Process:
            1. Verify old certificate belongs to user
            2. Issue new certificate with same subject DN
            3. Mark old certificate as superseded
            4. Return new certificate details

        The old certificate is not immediately revoked (grace period for transition).
        Users should install the new certificate and then the old one can be revoked.
        """
        old_cert = self.get_object()

        # Check permission
        if not (request.user == old_cert.user or request.user.is_superuser):
            raise PermissionDenied("You can only renew your own certificates")

        # Check if certificate can be renewed
        if old_cert.status == 'revoked':
            return Response(
                {'error': 'Cannot renew revoked certificate'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            validity_days = int(request.data.get('validity_days', 365))

            # Issue new certificate
            ca_manager = CAManager()
            cert_data = ca_manager.issue_user_certificate(
                ca=old_cert.ca,
                user=old_cert.user,
                validity_days=validity_days
            )

            # Create new certificate record
            new_cert = UserCertificate.objects.create(
                ca=old_cert.ca,
                user=old_cert.user,
                certificate=cert_data['certificate_pem'],
                private_key=cert_data['private_key_pem'],
                serial_number=cert_data['serial_number'],
                subject_dn=cert_data['subject_dn'],
                not_valid_before=cert_data['not_valid_before'],
                not_valid_after=cert_data['not_valid_after'],
                status='valid',
                issued_by=request.user
            )

            # Mark old certificate as superseded
            old_cert.status = 'superseded'
            old_cert.save()

            logger.info(
                f"Certificate {old_cert.serial_number} renewed as {new_cert.serial_number} "
                f"for user {old_cert.user.username}"
            )

            return Response({
                'status': 'success',
                'new_certificate_id': str(new_cert.id),
                'new_serial_number': new_cert.serial_number,
                'not_valid_after': new_cert.not_valid_after.isoformat(),
                'download_url': f'/api/v1/pki/certificates/{new_cert.id}/download/',
                'old_certificate_status': 'superseded'
            })

        except Exception as e:
            logger.error(f"Failed to renew certificate: {e}", exc_info=True)
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class CertificateRevocationListView(viewsets.ViewSet):
    """
    Certificate Revocation List (CRL) API

    Endpoint:
        GET /api/v1/pki/crl/ - Download CRL in PEM format

    The CRL contains all revoked certificates and should be:
    1. Downloaded periodically by nginx (ssl_crl directive)
    2. Checked by external systems verifying certificates
    3. Updated whenever a certificate is revoked

    CONFIGURATION:
        Add to nginx.conf:
            ssl_crl /etc/nginx/ssl/internal-ca.crl;

        Automate CRL updates:
            */30 * * * * python /path/to/manage.py export_crl --output /etc/nginx/ssl/internal-ca.crl && nginx -s reload
    """
    permission_classes = []  # Public endpoint

    @action(detail=False, methods=['get'])
    def list(self, request):
        """
        Download Certificate Revocation List
        """
        try:
            ca = CertificateAuthority.objects.filter(is_active=True).first()
            if not ca:
                return Response(
                    {'error': 'No active Certificate Authority'},
                    status=status.HTTP_404_NOT_FOUND
                )

            ca_manager = CAManager()
            crl_pem = ca_manager.generate_crl(ca)

            response = HttpResponse(crl_pem, content_type='application/x-pem-file')
            response['Content-Disposition'] = f'attachment; filename="{ca.name}-crl.pem"'

            return response

        except Exception as e:
            logger.error(f"Failed to generate CRL: {e}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
