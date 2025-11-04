# -*- coding: utf-8 -*-
#
"""
Issue User Certificate Command

Automatically issue certificates to users.
"""
import os
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from pki.models import CertificateAuthority, UserCertificate
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
        existing = UserCertificate.objects.filter(
            user=user,
            status='valid',
            not_valid_after__gt=timezone.now()
        ).first()

        if existing:
            self.stdout.write(self.style.WARNING(
                f'User already has valid certificate (expires: {existing.not_valid_after})'
            ))
            response = input('Issue new certificate anyway? [y/N]: ')
            if response.lower() != 'y':
                return

        # Issue certificate
        self.stdout.write(f'Issuing certificate to {user.username}...')

        ca_manager = CAManager()
        cert_data = ca_manager.issue_user_certificate(
            ca=ca,
            user=user,
            validity_days=validity_days
        )

        # Create certificate record
        user_cert = UserCertificate.objects.create(
            ca=ca,
            user=user,
            certificate=cert_data['certificate_pem'],
            private_key=cert_data['private_key_pem'],
            serial_number=cert_data['serial_number'],
            subject_dn=cert_data['subject_dn'],
            not_valid_before=cert_data['not_valid_before'],
            not_valid_after=cert_data['not_valid_after'],
            status='valid'
        )

        # Export to .p12
        if not output_path:
            output_path = f'{username}.p12'

        p12_data = ca_manager.export_pkcs12(
            certificate_pem=cert_data['certificate_pem'],
            private_key_pem=cert_data['private_key_pem'],
            ca_cert_pem=ca.certificate,
            password=p12_password.encode('utf-8')
        )

        with open(output_path, 'wb') as f:
            f.write(p12_data)

        self.stdout.write(self.style.SUCCESS(f'✓ Certificate issued'))
        self.stdout.write(f'Serial Number: {cert_data["serial_number"]}')
        self.stdout.write(f'Valid From: {cert_data["not_valid_before"]}')
        self.stdout.write(f'Valid Until: {cert_data["not_valid_after"]}')
        self.stdout.write(f'Output File: {output_path}')
        self.stdout.write(self.style.SUCCESS(f'\nUser should import {output_path} into their browser.'))


from django.utils import timezone
