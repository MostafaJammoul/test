# -*- coding: utf-8 -*-
#
"""
Management command to reset PKI state.

Features:
    * Reset the Certificate Authority serial counter (manually or auto-detected)
    * Regenerate a fresh Certificate Revocation List (CRL)
    * Optionally export the CRL to disk
"""
import os
from django.core.management.base import BaseCommand, CommandError
from django.db.models import Max
from django.utils import timezone

from pki.models import CertificateAuthority, Certificate, CertificateRevocationList
from pki.ca_manager import CAManager


class Command(BaseCommand):
    help = 'Reset CA serial counter and regenerate the certificate revocation list (CRL)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--serial',
            type=int,
            help='Manually set the next certificate serial number. '
                 'If omitted, the next serial will be max(existing)+1 or 1 if none exists.'
        )
        parser.add_argument(
            '--export-crl',
            dest='export_crl',
            type=str,
            help='Optional file path to export the regenerated CRL (PEM format).'
        )
        parser.add_argument(
            '--force',
            action='store_true',
            help='Overwrite the CRL export file if it already exists.'
        )

    def handle(self, *args, **options):
        ca = CertificateAuthority.objects.filter(is_active=True).first()
        if not ca:
            raise CommandError('No active Certificate Authority found. Run init_pki first.')

        requested_serial = options.get('serial')
        force_overwrite = options.get('force')
        export_path = options.get('export_crl')

        # Determine next serial number
        if requested_serial and requested_serial <= 0:
            raise CommandError('Serial number must be a positive integer.')

        if requested_serial:
            next_serial = requested_serial
        else:
            max_serial = self._get_max_serial(ca)
            next_serial = (max_serial + 1) if max_serial is not None else 1

        ca.serial_number = next_serial
        ca.save(update_fields=['serial_number'])

        self.stdout.write(self.style.SUCCESS(
            f'CA "{ca.name}" serial counter set to {ca.serial_number}'
        ))

        # Clear previous CRL entries for cleanliness
        deleted, _ = CertificateRevocationList.objects.filter(ca=ca).delete()
        if deleted:
            self.stdout.write(f'Removed {deleted} historical CRL record(s)')

        ca_manager = CAManager()
        crl_obj = ca_manager.generate_crl(ca)

        self.stdout.write(self.style.SUCCESS(
            f'Generated fresh CRL (valid until {crl_obj.next_update:%Y-%m-%d %H:%M:%S %Z})'
        ))

        if export_path:
            self._export_crl(crl_obj.crl_pem, export_path, force_overwrite)

        self.stdout.write(self.style.SUCCESS('PKI state reset complete.'))

    def _get_max_serial(self, ca):
        """
        Returns the highest numeric serial number issued by the CA.
        Serial numbers are stored as strings, so convert carefully.
        """
        queryset = Certificate.objects.filter(ca=ca).values_list('serial_number', flat=True)
        max_value = None
        for serial in queryset:
            try:
                serial_int = int(serial)
                if max_value is None or serial_int > max_value:
                    max_value = serial_int
            except (TypeError, ValueError):
                # Ignore non-numeric serials (should not happen with current implementation)
                continue
        return max_value

    def _export_crl(self, crl_pem, export_path, force):
        """
        Persist CRL PEM to disk with sane permissions.
        """
        export_dir = os.path.dirname(export_path)
        if export_dir and not os.path.exists(export_dir):
            os.makedirs(export_dir, mode=0o755, exist_ok=True)

        if os.path.exists(export_path) and not force:
            raise CommandError(
                f'CRL export path "{export_path}" already exists. '
                'Re-run with --force to overwrite.'
            )

        with open(export_path, 'w') as f:
            f.write(crl_pem)

        os.chmod(export_path, 0o644)
        self.stdout.write(self.style.SUCCESS(
            f'CRL exported to {os.path.abspath(export_path)} ({timezone.now():%Y-%m-%d %H:%M:%S})'
        ))
