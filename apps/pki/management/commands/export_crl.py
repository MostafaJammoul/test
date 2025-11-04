# -*- coding: utf-8 -*-
#
"""
Export Certificate Revocation List (CRL) for nginx
"""
import os
from datetime import timedelta
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.backends import default_backend

from pki.models import CertificateAuthority, Certificate


class Command(BaseCommand):
    help = 'Export Certificate Revocation List (CRL) for nginx ssl_crl'

    def add_arguments(self, parser):
        parser.add_argument(
            '--output',
            type=str,
            required=True,
            help='Output file path (e.g., data/certs/mtls/internal-ca.crl)'
        )
        parser.add_argument(
            '--force',
            action='store_true',
            help='Overwrite if file already exists'
        )

    def handle(self, *args, **options):
        output_path = options['output']
        force = options['force']

        # Check if file exists
        if os.path.exists(output_path) and not force:
            raise CommandError(
                f'File already exists: {output_path}\n'
                'Use --force to overwrite'
            )

        # Get CA certificate
        try:
            ca = CertificateAuthority.objects.filter(is_active=True).first()
            if not ca:
                raise CommandError('No active Certificate Authority found. Run: python manage.py init_pki')
        except Exception as e:
            raise CommandError(f'Failed to query CA: {e}')

        # Load CA private key
        try:
            ca_private_key = serialization.load_pem_private_key(
                ca.private_key.encode('utf-8'),
                password=None,
                backend=default_backend()
            )
        except Exception as e:
            raise CommandError(f'Failed to load CA private key: {e}')

        # Load CA certificate
        try:
            ca_cert = x509.load_pem_x509_certificate(
                ca.certificate.encode('utf-8'),
                default_backend()
            )
        except Exception as e:
            raise CommandError(f'Failed to load CA certificate: {e}')

        # Get revoked certificates
        revoked_certs = Certificate.objects.filter(ca=ca, revoked=True)

        # Build CRL
        crl_builder = x509.CertificateRevocationListBuilder()
        crl_builder = crl_builder.issuer_name(ca_cert.subject)
        crl_builder = crl_builder.last_update(timezone.now())
        crl_builder = crl_builder.next_update(timezone.now() + timedelta(days=7))

        # Add revoked certificates
        revoked_count = 0
        for cert in revoked_certs:
            try:
                revoked_cert = x509.RevokedCertificateBuilder().serial_number(
                    int(cert.serial_number)
                ).revocation_date(
                    cert.revocation_date or cert.created_at
                ).build(default_backend())

                crl_builder = crl_builder.add_revoked_certificate(revoked_cert)
                revoked_count += 1
            except Exception as e:
                self.stderr.write(self.style.WARNING(
                    f'Failed to add certificate {cert.serial_number} to CRL: {e}'
                ))

        # Sign CRL with CA private key
        try:
            crl = crl_builder.sign(
                private_key=ca_private_key,
                algorithm=hashes.SHA256(),
                backend=default_backend()
            )
        except Exception as e:
            raise CommandError(f'Failed to sign CRL: {e}')

        # Create directory if needed
        output_dir = os.path.dirname(output_path)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir, mode=0o755, exist_ok=True)
            self.stdout.write(self.style.SUCCESS(f'Created directory: {output_dir}'))

        # Write CRL
        try:
            with open(output_path, 'wb') as f:
                f.write(crl.public_bytes(serialization.Encoding.PEM))

            # Set permissions (readable by all)
            os.chmod(output_path, 0o644)

            self.stdout.write(self.style.SUCCESS(
                f'✓ CRL exported to: {output_path}\n'
                f'  Revoked certificates: {revoked_count}\n'
                f'  Last update: {timezone.now()}\n'
                f'  Next update: {timezone.now() + timedelta(days=7)}\n'
                f'\n'
                f'Use in nginx config:\n'
                f'  ssl_crl {os.path.abspath(output_path)};'
            ))

            if revoked_count == 0:
                self.stdout.write(self.style.WARNING(
                    '\n⚠ No revoked certificates found. CRL is empty.'
                ))

        except Exception as e:
            raise CommandError(f'Failed to write CRL: {e}')
