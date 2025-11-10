"""
Generate Certificates for Existing Users

This command creates certificates for users who don't have one yet.
Useful when PKI system is added to existing JumpServer installation.

Usage: python manage.py generate_missing_certs
"""
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from pki.models import CertificateAuthority, Certificate
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
from datetime import datetime, timedelta

User = get_user_model()


class Command(BaseCommand):
    help = 'Generate certificates for existing users without certificates'

    def add_arguments(self, parser):
        parser.add_argument(
            '--username',
            type=str,
            help='Generate certificate for specific user only'
        )
        parser.add_argument(
            '--days',
            type=int,
            default=365,
            help='Certificate validity in days (default: 365)'
        )

    def handle(self, *args, **options):
        username = options.get('username')
        days = options['days']

        # Get active CA
        ca = CertificateAuthority.objects.filter(is_active=True).first()
        if not ca:
            self.stdout.write(self.style.ERROR('No active CA found. Run create_ca first.'))
            return

        # Get users without certificates
        if username:
            users = User.objects.filter(username=username)
            if not users.exists():
                self.stdout.write(self.style.ERROR(f'User "{username}" not found'))
                return
        else:
            # Find all users without valid certificates
            users_with_certs = Certificate.objects.filter(
                is_revoked=False
            ).values_list('user_id', flat=True)
            users = User.objects.exclude(id__in=users_with_certs)

        if not users.exists():
            self.stdout.write(self.style.SUCCESS('All users already have certificates'))
            return

        self.stdout.write(f'Found {users.count()} user(s) without certificates')
        self.stdout.write('')

        # Load CA keys
        ca_key = serialization.load_pem_private_key(
            ca.private_key.encode(),
            password=None,
            backend=default_backend()
        )
        ca_cert = x509.load_pem_x509_certificate(
            ca.certificate.encode(),
            backend=default_backend()
        )

        success_count = 0
        error_count = 0

        for user in users:
            try:
                # Generate user key
                user_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

                # Get serial number
                serial_number = ca.serial_number
                ca.serial_number += 1
                ca.save(update_fields=['serial_number'])

                # Create certificate
                subject = x509.Name([
                    x509.NameAttribute(NameOID.COUNTRY_NAME, "PS"),
                    x509.NameAttribute(NameOID.ORGANIZATION_NAME, "JumpServer Blockchain"),
                    x509.NameAttribute(NameOID.COMMON_NAME, user.username),
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
                    subject_dn=f"CN={user.username},O=JumpServer Blockchain,C=PS",
                    issuer_dn=f"CN=JumpServer Root CA,O=JumpServer Blockchain,C=PS",
                    not_before=not_before,
                    not_after=not_after
                )

                self.stdout.write(
                    self.style.SUCCESS(f'✓ Certificate generated for {user.username} (ID: {cert_obj.id}, Serial: {serial_number})')
                )
                success_count += 1

            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(f'✗ Failed to generate certificate for {user.username}: {e}')
                )
                error_count += 1

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS(f'Completed: {success_count} successful, {error_count} errors'))

        if success_count > 0:
            self.stdout.write('')
            self.stdout.write('Users can now download their certificates from:')
            self.stdout.write('  Django Admin: http://192.168.148.154:8080/admin/pki/certificate/')
            self.stdout.write('  API: http://192.168.148.154:8080/api/v1/pki/certificates/<id>/download/')
