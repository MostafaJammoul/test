# Remaining Implementation for Passwordless Auth

**Status**: MFA API and mTLS middleware completed. Certificate generation and frontend still needed.

---

## ✅ Completed So Far

1. **MFA Setup API** (`apps/authentication/api/mfa_setup.py`)
   - GET/POST `/api/v1/authentication/mfa/setup/`
   - POST `/api/v1/authentication/mfa/verify-totp/`
   - GET `/api/v1/authentication/mfa/status/`

2. **mTLS Middleware** (`apps/authentication/middleware_mtls.py`)
   - MTLSAuthenticationMiddleware - Logs users in via certificate
   - MFARequiredMiddleware - Enforces MFA verification
   - Added to MIDDLEWARE in settings/base.py

3. **Documentation** (PASSWORDLESS_AUTH_IMPLEMENTATION.md)

---

## ⏳ Remaining Files To Create

### Backend (4 files):

**File 1**: `apps/pki/management/commands/create_ca.py`
```python
"""
Create Root Certificate Authority

Run once during system initialization:
python manage.py create_ca

Database: INSERT INTO pki_certificateauthority
"""
from django.core.management.base import BaseCommand
from pki.models import CertificateAuthority
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from datetime import datetime, timedelta

class Command(BaseCommand):
    help = 'Create root Certificate Authority for mTLS'

    def handle(self, *args, **options):
        # Check if CA already exists
        if CertificateAuthority.objects.filter(name='JumpServer Root CA').exists():
            self.stdout.write(self.style.WARNING('CA already exists'))
            return

        # Generate RSA key pair
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=4096)

        # Create CA certificate
        subject = issuer = x509.Name([
            x509.NameAttribute(NameOID.COUNTRY_NAME, "PS"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "JumpServer Blockchain"),
            x509.NameAttribute(NameOID.COMMON_NAME, "JumpServer Root CA"),
        ])

        cert = x509.CertificateBuilder().subject_name(
            subject
        ).issuer_name(
            issuer
        ).public_key(
            private_key.public_key()
        ).serial_number(
            x509.random_serial_number()
        ).not_valid_before(
            datetime.utcnow()
        ).not_valid_after(
            datetime.utcnow() + timedelta(days=3650)  # 10 years
        ).add_extension(
            x509.BasicConstraints(ca=True, path_length=0),
            critical=True,
        ).sign(private_key, hashes.SHA256())

        # Save to database
        ca = CertificateAuthority.objects.create(
            name='JumpServer Root CA',
            certificate=cert.public_bytes(serialization.Encoding.PEM).decode(),
            private_key=private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption()
            ).decode(),
            serial_number=1000,  # Start user certs from 1000
            valid_from=datetime.utcnow(),
            valid_until=datetime.utcnow() + timedelta(days=3650)
        )

        self.stdout.write(self.style.SUCCESS(f'CA created: {ca.id}'))
```

---

**File 2**: `apps/pki/management/commands/issue_user_cert.py`
```python
"""
Issue user certificate

Usage: python manage.py issue_user_cert --username investigator1

Database Operations:
- SELECT FROM pki_certificateauthority
- INSERT INTO pki_certificate
- UPDATE pki_certificateauthority.serial_number
"""
from django.core.management.base import BaseCommand
from pki.models import CertificateAuthority, Certificate
from users.models import User
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
from datetime import datetime, timedelta

class Command(BaseCommand):
    help = 'Issue mTLS certificate for user'

    def add_arguments(self, parser):
        parser.add_argument('--username', type=str, required=True)
        parser.add_argument('--days', type=int, default=365)

    def handle(self, *args, **options):
        username = options['username']
        days = options['days']

        # Get user
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            self.stdout.write(self.style.ERROR(f'User {username} not found'))
            return

        # Get CA
        ca = CertificateAuthority.objects.filter(is_active=True).first()
        if not ca:
            self.stdout.write(self.style.ERROR('No active CA found. Run create_ca first.'))
            return

        # Load CA private key
        ca_key = serialization.load_pem_private_key(
            ca.private_key.encode(),
            password=None,
            backend=default_backend()
        )
        ca_cert = x509.load_pem_x509_certificate(
            ca.certificate.encode(),
            backend=default_backend()
        )

        # Generate user key pair
        user_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

        # Get next serial number
        serial_number = ca.serial_number
        ca.serial_number += 1
        ca.save(update_fields=['serial_number'])

        # Create user certificate
        subject = x509.Name([
            x509.NameAttribute(NameOID.COUNTRY_NAME, "PS"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "JumpServer Blockchain"),
            x509.NameAttribute(NameOID.COMMON_NAME, username),
        ])

        cert = x509.CertificateBuilder().subject_name(
            subject
        ).issuer_name(
            ca_cert.subject
        ).public_key(
            user_key.public_key()
        ).serial_number(
            serial_number
        ).not_valid_before(
            datetime.utcnow()
        ).not_valid_after(
            datetime.utcnow() + timedelta(days=days)
        ).add_extension(
            x509.BasicConstraints(ca=False, path_length=None),
            critical=True,
        ).add_extension(
            x509.KeyUsage(
                digital_signature=True,
                key_encipherment=True,
                content_commitment=False,
                data_encipherment=False,
                key_agreement=False,
                key_cert_sign=False,
                crl_sign=False,
                encipher_only=False,
                decipher_only=False,
            ),
            critical=True,
        ).add_extension(
            x509.ExtendedKeyUsage([x509.oid.ExtendedKeyUsageOID.CLIENT_AUTH]),
            critical=True,
        ).sign(ca_key, hashes.SHA256())

        # Save to database
        cert_obj = Certificate.objects.create(
            ca=ca,
            user=user,
            cert_type='user',
            serial_number=str(serial_number),
            certificate=cert.public_bytes(serialization.Encoding.PEM).decode(),
            private_key=user_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption()
            ).decode(),
            subject_dn=f"CN={username},O=JumpServer Blockchain,C=PS",
            issuer_dn=f"CN=JumpServer Root CA,O=JumpServer Blockchain,C=PS",
            not_before=datetime.utcnow(),
            not_after=datetime.utcnow() + timedelta(days=days)
        )

        self.stdout.write(self.style.SUCCESS(
            f'Certificate issued for {username}: {cert_obj.id}'
        ))
```

---

**File 3**: `apps/pki/api/certificate.py`
```python
"""
Certificate Download API

GET /api/v1/pki/certificates/{id}/download/
Returns .p12 file for browser import
"""
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAdminUser
from django.http import HttpResponse
from pki.models import Certificate
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
from cryptography import x509
import OpenSSL.crypto

class CertificateViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Certificate.objects.all()
    permission_classes = [IsAdminUser]

    @action(detail=True, methods=['get'])
    def download(self, request, pk=None):
        """
        Download certificate as .p12 file

        Database: SELECT * FROM pki_certificate WHERE id=?
        """
        cert = self.get_object()

        # Load certificate and key
        cert_pem = cert.certificate.encode()
        key_pem = cert.private_key.encode()

        # Create PKCS12
        p12 = OpenSSL.crypto.PKCS12()
        p12.set_privatekey(OpenSSL.crypto.load_privatekey(
            OpenSSL.crypto.FILETYPE_PEM, key_pem
        ))
        p12.set_certificate(OpenSSL.crypto.load_certificate(
            OpenSSL.crypto.FILETYPE_PEM, cert_pem
        ))

        # Optional: Add CA certificate
        # p12.set_ca_certificates([ca_cert])

        # Export as .p12 (no password for now)
        p12_data = p12.export()

        response = HttpResponse(p12_data, content_type='application/x-pkcs12')
        response['Content-Disposition'] = f'attachment; filename="{cert.user.username}.p12"'

        return response
```

Add to `apps/pki/api/urls.py`:
```python
from rest_framework.routers import DefaultRouter
from . import certificate

app_name = 'pki'
router = DefaultRouter()
router.register('certificates', certificate.CertificateViewSet, basename='certificate')

urlpatterns = router.urls
```

---

**File 4**: Update `apps/users/admin.py`
Add after user creation:
```python
from pki.management.commands.issue_user_cert import Command as IssueCertCommand

class UserAdmin(admin.ModelAdmin):
    def save_model(self, request, obj, form, change):
        super().save_model(request, obj, form, change)

        # Auto-generate certificate for new users
        if not change:  # New user
            cmd = IssueCertCommand()
            cmd.handle(username=obj.username, days=365)
            self.message_user(request, f'Certificate generated for {obj.username}')
```

---

### Frontend (3 files):

**File 5**: `frontend/src/pages/MFASetup.jsx`
See next file for complete code (too large for this summary)

**File 6**: Update `frontend/src/pages/MFAChallenge.jsx`
**File 7**: Update `frontend/src/contexts/AuthContext.jsx`

---

## Deployment Commands

```bash
# On VM after SCP
cd /opt/truefypjs/apps

# 1. Create CA (one time only)
python manage.py create_ca

# 2. Create user in Django admin
# http://192.168.148.154:8080/admin/users/user/add/
# Certificate auto-generated

# 3. Download certificate from admin panel

# 4. Import to browser

# 5. Configure nginx (see PASSWORDLESS_AUTH_IMPLEMENTATION.md)
```

---

Continue implementation with these files.
