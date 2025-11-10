"""
Create Root Certificate Authority

Run once during system initialization:
python manage.py create_ca

Database Operations:
- INSERT INTO pki_certificateauthority (certificate, private_key, serial_number, ...)
"""
from django.core.management.base import BaseCommand
from pki.models import CertificateAuthority
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from datetime import datetime, timedelta


class Command(BaseCommand):
    help = 'Create root Certificate Authority for mTLS authentication'

    def handle(self, *args, **options):
        # Check if CA already exists
        if CertificateAuthority.objects.filter(name='JumpServer Root CA').exists():
            self.stdout.write(self.style.WARNING('CA already exists. Use existing CA.'))
            ca = CertificateAuthority.objects.get(name='JumpServer Root CA')
            self.stdout.write(self.style.SUCCESS(f'Existing CA ID: {ca.id}'))
            return

        self.stdout.write('Creating new Root Certificate Authority...')

        # Generate RSA key pair (4096 bits for CA)
        private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=4096
        )

        # Create CA certificate
        subject = issuer = x509.Name([
            x509.NameAttribute(NameOID.COUNTRY_NAME, "PS"),
            x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, "Palestine"),
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
        ).add_extension(
            x509.KeyUsage(
                digital_signature=True,
                key_encipherment=False,
                content_commitment=False,
                data_encipherment=False,
                key_agreement=False,
                key_cert_sign=True,
                crl_sign=True,
                encipher_only=False,
                decipher_only=False,
            ),
            critical=True,
        ).sign(private_key, hashes.SHA256())

        # Save to database
        # Database: INSERT INTO pki_certificateauthority
        ca = CertificateAuthority.objects.create(
            name='JumpServer Root CA',
            certificate=cert.public_bytes(serialization.Encoding.PEM).decode(),
            private_key=private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption()
            ).decode(),
            serial_number=1000,  # Start user certificates from serial 1000
            valid_from=datetime.utcnow(),
            valid_until=datetime.utcnow() + timedelta(days=3650)
        )

        self.stdout.write(self.style.SUCCESS('✓ Root CA created successfully'))
        self.stdout.write(f'  CA ID: {ca.id}')
        self.stdout.write(f'  Valid from: {ca.valid_from}')
        self.stdout.write(f'  Valid until: {ca.valid_until}')
        self.stdout.write(f'  Next serial: {ca.serial_number}')
        self.stdout.write('')
        self.stdout.write('You can now issue user certificates with:')
        self.stdout.write('  python manage.py issue_user_cert --username <username>')
