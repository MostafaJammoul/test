# -*- coding: utf-8 -*-
#
"""
Export Internal CA certificate for nginx configuration
"""
import os
from django.core.management.base import BaseCommand, CommandError
from pki.models import CertificateAuthority


class Command(BaseCommand):
    help = 'Export Internal CA certificate (PEM format) for nginx ssl_client_certificate'

    def add_arguments(self, parser):
        parser.add_argument(
            '--output',
            type=str,
            required=True,
            help='Output file path (e.g., data/certs/mtls/internal-ca.crt)'
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

        # Create directory if needed
        output_dir = os.path.dirname(output_path)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir, mode=0o755, exist_ok=True)
            self.stdout.write(self.style.SUCCESS(f'Created directory: {output_dir}'))

        # Write CA certificate
        try:
            with open(output_path, 'w') as f:
                f.write(ca.certificate)

            # Set permissions (readable by all)
            os.chmod(output_path, 0o644)

            self.stdout.write(self.style.SUCCESS(
                f'✓ CA certificate exported to: {output_path}\n'
                f'  CA Name: {ca.name}\n'
                f'  Valid from: {ca.valid_from}\n'
                f'  Valid until: {ca.valid_until}\n'
                f'\n'
                f'Use in nginx config:\n'
                f'  ssl_client_certificate {os.path.abspath(output_path)};'
            ))
        except Exception as e:
            raise CommandError(f'Failed to write certificate: {e}')
