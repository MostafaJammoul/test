"""
Issue User Certificate for mTLS Authentication

Usage: python manage.py issue_user_cert --username investigator1

Database Operations:
- SELECT FROM pki_certificateauthority WHERE is_active=TRUE
- SELECT FROM users_user WHERE username=?
- INSERT INTO pki_certificate (ca, user, serial_number, certificate, private_key, ...)
- UPDATE pki_certificateauthority SET serial_number = serial_number + 1
"""
from django.core.management.base import BaseCommand
from pki.models import CertificateAuthority, Certificate
from django.contrib.auth import get_user_model
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
from datetime import datetime, timedelta

User = get_user_model()


class Command(BaseCommand):
    help = 'Issue mTLS client certificate for user authentication'

    def add_arguments(self, parser):
        parser.add_argument('--username', type=str, required=True, help='Username to issue certificate for')
        parser.add_argument('--days', type=int, default=365, help='Certificate validity in days (default: 365)')

    def handle(self, *args, **options):
        username = options['username']
        days = options['days']

        # 1. Get user from database
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            self.stdout.write(self.style.ERROR(f'User "{username}" not found'))
            return

        # 2. Get active CA
        ca = CertificateAuthority.objects.filter(is_active=True).first()
        if not ca:
            self.stdout.write(self.style.ERROR('No active CA found. Run create_ca first.'))
            return

        # 3. Load CA keys
        ca_key = serialization.load_pem_private_key(
            ca.private_key.encode(),
            password=None,
            backend=default_backend()
        )
        ca_cert = x509.load_pem_x509_certificate(
            ca.certificate.encode(),
            backend=default_backend()
        )

        # 4. Generate user key
        user_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

        # 5. Get serial number
        serial_number = ca.serial_number
        ca.serial_number += 1
        ca.save(update_fields=['serial_number'])

        # 6. Create certificate
        subject = x509.Name([
            x509.NameAttribute(NameOID.COUNTRY_NAME, "PS"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "JumpServer Blockchain"),
            x509.NameAttribute(NameOID.COMMON_NAME, username),
        ])

        not_before = datetime.utcnow()
        not_after = not_before + timedelta(days=days)

        cert = x509.CertificateBuilder().subject_name(
            subject
        ).issuer_name(
            ca_cert.subject
        ).public_key(
            user_key.public_key()
        ).serial_number(
            serial_number
        ).not_valid_before(
            not_before
        ).not_valid_after(
            not_after
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

        # 7. Save to database
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
            not_before=not_before,
            not_after=not_after
        )

        self.stdout.write(self.style.SUCCESS(f'Certificate issued: {cert_obj.id}'))
