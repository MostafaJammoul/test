# -*- coding: utf-8 -*-
#
"""
Issue User Certificate Command

Automatically issue certificates to users.
"""
import os
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
from cryptography import x509
from pki.models import CertificateAuthority, Certificate
from pki.ca_manager import CAManager

User = get_user_model()


class Command(BaseCommand):
    help = 'Issue certificate to a user'

    def add_arguments(self, parser):
        parser.add_argument('--username', type=str, required=True, help='Username')
        parser.add_argument('--validity-days', type=int, default=365, help='Certificate validity in days')
        parser.add_argument('--output', type=str, help='Output path for .p12 file')
        parser.add_argument('--password', type=str, default='', help='Password for .p12 file (default: empty)')

    def handle(self, *args, **options):
        username = options['username']
        validity_days = options['validity_days']
        p12_password = options['password']
        output_path = options.get('output')

        # Get user
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            self.stdout.write(self.style.ERROR(f'User "{username}" not found'))
            return

        # Get active CA
        ca = CertificateAuthority.objects.filter(is_active=True).first()
        if not ca:
            self.stdout.write(self.style.ERROR('No active CA found. Run: python manage.py init_pki'))
            return

        # Check for existing valid certificate
        existing = Certificate.objects.filter(
            user=user,
            revoked=False,
            not_after__gt=timezone.now()
        ).first()

        if existing:
            self.stdout.write(self.style.WARNING(
                f'User already has valid certificate (expires: {existing.not_after})'
            ))
            self.stdout.write('Issuing new certificate anyway...')

        # Issue certificate
        self.stdout.write(f'Issuing certificate to {user.username}...')

        ca_manager = CAManager()
        # issue_user_certificate() returns a Certificate object, not a dict
        certificate = ca_manager.issue_user_certificate(
            ca=ca,
            user=user,
            validity_days=validity_days
        )

        # Export to .p12
        if not output_path:
            output_path = f'{username}.p12'

        # Convert PEM certificate and key to PKCS#12 format
        cert = x509.load_pem_x509_certificate(
            certificate.certificate.encode('utf-8'),
            default_backend()
        )
        key = serialization.load_pem_private_key(
            certificate.private_key.encode('utf-8'),
            password=None,
            backend=default_backend()
        )
        ca_cert = x509.load_pem_x509_certificate(
            ca.certificate.encode('utf-8'),
            default_backend()
        )

        # Create PKCS#12
        from cryptography.hazmat.primitives.serialization import pkcs12
        p12_data = pkcs12.serialize_key_and_certificates(
            name=username.encode('utf-8'),
            key=key,
            cert=cert,
            cas=[ca_cert],
            encryption_algorithm=serialization.BestAvailableEncryption(p12_password.encode('utf-8'))
                if p12_password else serialization.NoEncryption()
        )

        # Ensure output directory exists
        output_dir = os.path.dirname(output_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)

        with open(output_path, 'wb') as f:
            f.write(p12_data)

        self.stdout.write(self.style.SUCCESS(f'✓ Certificate issued'))
        self.stdout.write(f'Serial Number: {certificate.serial_number}')
        self.stdout.write(f'Valid From: {certificate.not_before}')
        self.stdout.write(f'Valid Until: {certificate.not_after}')
        self.stdout.write(f'Output File: {output_path}')
        if p12_password:
            self.stdout.write(f'Password: {p12_password}')
        self.stdout.write(self.style.SUCCESS(f'\nUser should import {output_path} into their browser.'))
