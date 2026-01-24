"""
Certificate Download API

GET /api/v1/pki/certificates/{id}/download/
Returns .p12 file for browser import

Database: SELECT * FROM pki_certificate WHERE id=?
"""
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.http import HttpResponse
from pki.models import Certificate
from pki.api.serializers import CertificateSerializer
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
from cryptography import x509
from OpenSSL import crypto


class CertificateViewSet(viewsets.ReadOnlyModelViewSet):
    """
    API endpoint for certificate management

    list: Get all certificates
    retrieve: Get single certificate
    download: Download certificate as .p12 file
    """
    queryset = Certificate.objects.all()
    serializer_class = CertificateSerializer
    permission_classes = [IsAuthenticated]

    @action(detail=True, methods=['get'])
    def download(self, request, pk=None):
        """
        Download certificate as PKCS#12 (.p12) file for browser import
        
        Database: SELECT * FROM pki_certificate WHERE id=?
        """
        cert = self.get_object()

        # Ensure user can only download their own certificate (or admin can download any)
        if not request.user.is_superuser and cert.user != request.user:
            return Response({
                'error': 'You can only download your own certificate'
            }, status=status.HTTP_403_FORBIDDEN)

        # Load certificate and private key
        cert_pem = cert.certificate.encode()
        key_pem = cert.private_key.encode()

        # Also load CA certificate
        ca_pem = cert.ca.certificate.encode()

        # Create PKCS12 bundle
        p12 = crypto.PKCS12()
        
        # Set private key
        p12.set_privatekey(crypto.load_privatekey(crypto.FILETYPE_PEM, key_pem))
        
        # Set user certificate
        p12.set_certificate(crypto.load_certificate(crypto.FILETYPE_PEM, cert_pem))
        
        # Set CA certificate chain
        p12.set_ca_certificates([crypto.load_certificate(crypto.FILETYPE_PEM, ca_pem)])

        # Set friendly name
        p12.set_friendlyname(f"{cert.user.username}@jumpserver".encode())

        # Export as .p12 (no password - user will set one during import)
        p12_data = p12.export()

        # Return as downloadable file
        response = HttpResponse(p12_data, content_type='application/x-pkcs12')
        response['Content-Disposition'] = f'attachment; filename="{cert.user.username}.p12"'
        
        return response
