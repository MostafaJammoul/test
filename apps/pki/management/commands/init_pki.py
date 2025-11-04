# -*- coding: utf-8 -*-
#
"""
Automated PKI Initialization Command

Automatically creates Internal CA and exports certificates.
Run once during initial deployment.
"""
import os
from django.core.management.base import BaseCommand
from django.conf import settings
from pki.models import CertificateAuthority
from pki.ca_manager import CAManager


class Command(BaseCommand):
    help = 'Initialize PKI system (create Internal CA and export certificates)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--ca-name',
            type=str,
            default='JumpServer Internal CA',
            help='Name of the Certificate Authority'
        )
        parser.add_argument(
            '--validity-years',
            type=int,
            default=10,
            help='CA certificate validity in years'
        )
        parser.add_argument(
            '--key-size',
            type=int,
            default=4096,
            help='RSA key size for CA'
        )
        parser.add_argument(
            '--export-dir',
            type=str,
            default='/etc/jumpserver/certs/internal-ca',
            help='Directory to export CA certificate'
        )
        parser.add_argument(
            '--force',
            action='store_true',
            help='Force recreate CA if already exists'
        )

    def handle(self, *args, **options):
        ca_name = options['ca_name']
        validity_years = options['validity_years']
        key_size = options['key_size']
        export_dir = options['export_dir']
        force = options['force']

        # Check if CA already exists
        existing_ca = CertificateAuthority.objects.filter(name=ca_name, is_active=True).first()

        if existing_ca and not force:
            self.stdout.write(self.style.WARNING(
                f'CA "{ca_name}" already exists. Use --force to recreate.'
            ))
            ca = existing_ca
        else:
            if existing_ca and force:
                self.stdout.write(self.style.WARNING(f'Deactivating existing CA "{ca_name}"...'))
                existing_ca.is_active = False
                existing_ca.save()

            # Create new CA
            self.stdout.write(self.style.SUCCESS('Creating Internal CA...'))

            ca_manager = CAManager()
            # Note: create_ca() accepts validity_days, not validity_years
            # Convert years to days
            validity_days_calculated = validity_years * 365
            ca = ca_manager.create_ca(
                name=ca_name,
                validity_days=validity_days_calculated
            )

            self.stdout.write(self.style.SUCCESS(
                f'✓ CA created: {ca.name} (Serial: {ca.serial_number})'
            ))

        # Export CA certificate
        self.stdout.write('Exporting CA certificate...')

        # Create export directory
        os.makedirs(export_dir, exist_ok=True)

        # Export to multiple formats
        ca_cert_path = os.path.join(export_dir, 'ca.crt')
        ca_cert_pem_path = os.path.join(export_dir, 'ca.pem')

        with open(ca_cert_path, 'w') as f:
            f.write(ca.certificate)

        with open(ca_cert_pem_path, 'w') as f:
            f.write(ca.certificate)

        # Set permissions
        os.chmod(ca_cert_path, 0o644)
        os.chmod(ca_cert_pem_path, 0o644)

        self.stdout.write(self.style.SUCCESS(f'✓ CA certificate exported to:'))
        self.stdout.write(f'  - {ca_cert_path}')
        self.stdout.write(f'  - {ca_cert_pem_path}')

        # Export to nginx directory if it exists
        nginx_ssl_dir = '/etc/nginx/ssl'
        if os.path.exists(nginx_ssl_dir) and os.access(nginx_ssl_dir, os.W_OK):
            nginx_ca_path = os.path.join(nginx_ssl_dir, 'internal-ca.crt')
            with open(nginx_ca_path, 'w') as f:
                f.write(ca.certificate)
            os.chmod(nginx_ca_path, 0o644)
            self.stdout.write(self.style.SUCCESS(f'✓ CA certificate copied to nginx: {nginx_ca_path}'))
        else:
            self.stdout.write(self.style.WARNING(
                f'⚠ Could not write to {nginx_ssl_dir}. '
                f'Manually copy {ca_cert_path} to nginx SSL directory.'
            ))

        # Summary
        self.stdout.write(self.style.SUCCESS('\n' + '='*70))
        self.stdout.write(self.style.SUCCESS('PKI INITIALIZATION COMPLETE'))
        self.stdout.write(self.style.SUCCESS('='*70))
        self.stdout.write(f'CA Name: {ca.name}')
        self.stdout.write(f'Serial Number: {ca.serial_number}')
        self.stdout.write(f'Certificate Path: {ca_cert_path}')
        self.stdout.write(self.style.SUCCESS('\nNext steps:'))
        self.stdout.write('1. Configure nginx to use the CA certificate')
        self.stdout.write('2. Issue user certificates: python manage.py issue_user_cert --username <user>')
        self.stdout.write('3. Users import .p12 files into their browsers')
