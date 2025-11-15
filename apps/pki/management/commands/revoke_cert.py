"""
Management command to revoke a certificate

Usage:
    python manage.py revoke_cert <username> [reason]
    python manage.py revoke_cert --serial <serial_number> [reason]

Examples:
    python manage.py revoke_cert john "User left company"
    python manage.py revoke_cert --serial 12345 "Key compromised"
"""
from django.core.management.base import BaseCommand, CommandError
from django.contrib.auth import get_user_model
from pki.models import Certificate
from datetime import datetime

User = get_user_model()


class Command(BaseCommand):
    help = 'Revoke a user certificate and update CRL'

    def add_arguments(self, parser):
        parser.add_argument(
            'username',
            nargs='?',
            type=str,
            help='Username of the certificate to revoke'
        )
        parser.add_argument(
            '--serial',
            type=str,
            help='Certificate serial number to revoke'
        )
        parser.add_argument(
            'reason',
            nargs='?',
            default='Revoked by administrator',
            type=str,
            help='Reason for revocation'
        )

    def handle(self, *args, **options):
        username = options.get('username')
        serial = options.get('serial')
        reason = options.get('reason')

        if not username and not serial:
            raise CommandError('You must provide either username or --serial')

        # Find certificate
        if serial:
            try:
                cert = Certificate.objects.get(serial_number=serial, revoked=False)
            except Certificate.DoesNotExist:
                raise CommandError(f'Certificate with serial {serial} not found or already revoked')
        else:
            try:
                user = User.objects.get(username=username)
                cert = Certificate.objects.get(user=user, revoked=False)
            except User.DoesNotExist:
                raise CommandError(f'User {username} not found')
            except Certificate.DoesNotExist:
                raise CommandError(f'No active certificate found for user {username}')

        # Confirm revocation
        self.stdout.write(self.style.WARNING('About to revoke certificate:'))
        self.stdout.write(f'  User: {cert.user.username}')
        self.stdout.write(f'  Serial: {cert.serial_number}')
        self.stdout.write(f'  Subject DN: {cert.subject_dn}')
        self.stdout.write(f'  Valid until: {cert.not_after}')
        self.stdout.write(f'  Reason: {reason}')
        self.stdout.write('')

        confirm = input('Are you sure you want to revoke this certificate? (yes/no): ')
        if confirm.lower() != 'yes':
            self.stdout.write(self.style.WARNING('Revocation cancelled'))
            return

        # Revoke certificate
        cert.revoked = True
        cert.revocation_date = datetime.utcnow()
        cert.revocation_reason = reason
        cert.save()

        self.stdout.write(self.style.SUCCESS(f'✓ Certificate {cert.serial_number} revoked'))

        # Update CRL
        self.stdout.write('')
        self.stdout.write('Updating Certificate Revocation List...')
        from django.core.management import call_command
        call_command('update_crl')

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('Certificate revoked successfully!'))
        self.stdout.write('')
        self.stdout.write('Next steps:')
        self.stdout.write(f'  1. User {cert.user.username} will be unable to authenticate via mTLS')
        self.stdout.write('  2. nginx will reject their certificate (via CRL check)')
        self.stdout.write('  3. To issue new certificate: python manage.py issue_user_cert ' + cert.user.username)
