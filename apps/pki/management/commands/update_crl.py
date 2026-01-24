"""
Management command to update Certificate Revocation List (CRL)

Usage:
    python manage.py update_crl

This command should be run:
- After revoking a certificate
- Periodically (e.g., daily via cron) to keep CRL up-to-date
"""
from django.core.management.base import BaseCommand
from pki.models import CertificateAuthority, Certificate
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.backends import default_backend
from datetime import datetime, timedelta
import os


class Command(BaseCommand):
    help = 'Generate and export Certificate Revocation List (CRL)'

    def handle(self, *args, **options):
        self.stdout.write('Generating Certificate Revocation List...')

        # Get active CA
        ca = CertificateAuthority.objects.filter(is_active=True).first()
        if not ca:
            self.stdout.write(self.style.ERROR('No active Certificate Authority found'))
            return

        # Load CA private key and certificate
        ca_key = serialization.load_pem_private_key(
            ca.private_key.encode(),
            password=None,
            backend=default_backend()
        )
        ca_cert = x509.load_pem_x509_certificate(
            ca.certificate.encode(),
            backend=default_backend()
        )

        # Get all revoked certificates
        revoked_certs = Certificate.objects.filter(ca=ca, revoked=True)
        self.stdout.write(f'Found {revoked_certs.count()} revoked certificates')

        # Build CRL
        crl_builder = x509.CertificateRevocationListBuilder()
        crl_builder = crl_builder.issuer_name(ca_cert.subject)
        crl_builder = crl_builder.last_update(datetime.utcnow())
        crl_builder = crl_builder.next_update(datetime.utcnow() + timedelta(days=30))

        # Add revoked certificates to CRL
        for cert in revoked_certs:
            try:
                revoked_cert = x509.RevokedCertificateBuilder().serial_number(
                    int(cert.serial_number)
                ).revocation_date(
                    cert.revocation_date or datetime.utcnow()
                ).build(default_backend())
                crl_builder = crl_builder.add_revoked_certificate(revoked_cert)
            except Exception as e:
                self.stdout.write(self.style.WARNING(
                    f'Failed to add certificate {cert.serial_number}: {e}'
                ))

        # Sign and build CRL
        crl = crl_builder.sign(
            private_key=ca_key,
            algorithm=hashes.SHA256(),
            backend=default_backend()
        )

        # Export CRL to filesystem
        cert_dir = os.path.join('..', 'data', 'certs', 'mtls')
        os.makedirs(cert_dir, exist_ok=True)

        crl_path = os.path.join(cert_dir, 'internal-ca.crl')
        with open(crl_path, 'wb') as f:
            f.write(crl.public_bytes(serialization.Encoding.PEM))

        self.stdout.write(self.style.SUCCESS(
            f'✓ CRL generated with {revoked_certs.count()} revoked certificates'
        ))
        self.stdout.write(self.style.SUCCESS(
            f'✓ CRL exported to {crl_path}'
        ))
        self.stdout.write('')
        self.stdout.write('Next steps:')
        self.stdout.write('  1. Reload nginx: sudo systemctl reload nginx')
        self.stdout.write('  2. CRL will be valid for 30 days')
        self.stdout.write('  3. Run this command again after revoking certificates')
