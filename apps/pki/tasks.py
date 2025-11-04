# -*- coding: utf-8 -*-
#
"""
PKI Automated Tasks

Background tasks for certificate renewal and CRL updates.
"""
import os
import logging
from datetime import timedelta
from django.utils import timezone
from django.conf import settings
from common.celery_decorator import register_as_period_task
from .models import CertificateAuthority, UserCertificate
from .ca_manager import CAManager

logger = logging.getLogger(__name__)


@register_as_period_task(crontab="0 2 * * *")  # Daily at 2 AM
def renew_expiring_user_certificates(self):
    """
    Automatically renew user certificates expiring within 30 days

    This task:
    1. Finds certificates expiring in 30 days
    2. Issues new certificates with same subject DN
    3. Marks old certificates as superseded
    4. Sends notification to users (TODO: integrate with notifications app)
    """
    logger.info("Starting automatic certificate renewal...")

    ca_manager = CAManager()
    renewal_threshold = timezone.now() + timedelta(days=30)

    # Find certificates expiring soon
    expiring_certs = UserCertificate.objects.filter(
        status='valid',
        not_valid_after__lte=renewal_threshold,
        not_valid_after__gt=timezone.now()
    )

    renewed_count = 0
    failed_count = 0

    for old_cert in expiring_certs:
        try:
            # Issue new certificate
            cert_data = ca_manager.issue_user_certificate(
                ca=old_cert.ca,
                user=old_cert.user,
                validity_days=365
            )

            # Create new certificate record
            new_cert = UserCertificate.objects.create(
                ca=old_cert.ca,
                user=old_cert.user,
                certificate=cert_data['certificate_pem'],
                private_key=cert_data['private_key_pem'],
                serial_number=cert_data['serial_number'],
                subject_dn=cert_data['subject_dn'],
                not_valid_before=cert_data['not_valid_before'],
                not_valid_after=cert_data['not_valid_after'],
                status='valid'
            )

            # Mark old certificate as superseded
            old_cert.status = 'superseded'
            old_cert.save()

            logger.info(
                f"Renewed certificate for {old_cert.user.username}: "
                f"{old_cert.serial_number} → {new_cert.serial_number}"
            )

            # TODO: Send notification to user
            # from notifications.models import SystemNotification
            # SystemNotification.objects.create(
            #     user=old_cert.user,
            #     title='Certificate Renewed',
            #     message=f'Your certificate has been automatically renewed. '
            #             f'Download new certificate from /api/v1/pki/certificates/{new_cert.id}/download/'
            # )

            renewed_count += 1

        except Exception as e:
            logger.error(f"Failed to renew certificate for {old_cert.user.username}: {e}")
            failed_count += 1

    logger.info(
        f"Certificate renewal complete: {renewed_count} renewed, {failed_count} failed"
    )

    return {
        'renewed': renewed_count,
        'failed': failed_count
    }


@register_as_period_task(crontab="0 */6 * * *")  # Every 6 hours
def update_certificate_revocation_list(self):
    """
    Generate and export CRL (Certificate Revocation List)

    This task:
    1. Generates CRL from all revoked certificates
    2. Exports to /etc/nginx/ssl/internal-ca.crl
    3. Reloads nginx to apply changes
    """
    logger.info("Updating Certificate Revocation List...")

    try:
        # Get active CA
        ca = CertificateAuthority.objects.filter(is_active=True).first()
        if not ca:
            logger.warning("No active CA found, skipping CRL update")
            return {'status': 'skipped', 'reason': 'no_active_ca'}

        # Generate CRL
        ca_manager = CAManager()
        crl_pem = ca_manager.generate_crl(ca)

        # Export to nginx directory
        crl_paths = [
            '/etc/nginx/ssl/internal-ca.crl',
            '/etc/jumpserver/certs/internal-ca/ca.crl'
        ]

        exported_count = 0
        for crl_path in crl_paths:
            crl_dir = os.path.dirname(crl_path)
            if os.path.exists(crl_dir) and os.access(crl_dir, os.W_OK):
                with open(crl_path, 'w') as f:
                    f.write(crl_pem)
                os.chmod(crl_path, 0o644)
                logger.info(f"CRL exported to {crl_path}")
                exported_count += 1

        if exported_count == 0:
            logger.warning("Could not export CRL to any location (permission denied)")
            return {'status': 'failed', 'reason': 'permission_denied'}

        # Reload nginx to apply new CRL
        try:
            import subprocess
            result = subprocess.run(
                ['nginx', '-s', 'reload'],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                logger.info("Nginx reloaded successfully")
            else:
                logger.warning(f"Nginx reload failed: {result.stderr}")
        except Exception as e:
            logger.warning(f"Could not reload nginx: {e}")

        logger.info("CRL update complete")
        return {'status': 'success', 'exported_to': exported_count}

    except Exception as e:
        logger.error(f"Failed to update CRL: {e}")
        return {'status': 'error', 'message': str(e)}


@register_as_period_task(crontab="0 0 * * 0")  # Weekly on Sunday
def revoke_expired_certificates(self):
    """
    Mark expired certificates as revoked

    This is a cleanup task to ensure database state matches reality.
    """
    logger.info("Revoking expired certificates...")

    expired_certs = UserCertificate.objects.filter(
        status='valid',
        not_valid_after__lt=timezone.now()
    )

    count = expired_certs.update(status='expired')
    logger.info(f"Marked {count} expired certificates")

    return {'revoked': count}


@register_as_period_task(crontab="0 3 * * *")  # Daily at 3 AM
def send_certificate_expiry_warnings(self):
    """
    Send notifications to users with expiring certificates

    Sends warnings at 30, 14, 7, and 1 days before expiry.
    """
    logger.info("Checking for expiring certificates...")

    warning_days = [30, 14, 7, 1]
    warned_count = 0

    for days in warning_days:
        expiry_date = timezone.now() + timedelta(days=days)
        expiry_start = expiry_date - timedelta(hours=12)
        expiry_end = expiry_date + timedelta(hours=12)

        expiring_certs = UserCertificate.objects.filter(
            status='valid',
            not_valid_after__gte=expiry_start,
            not_valid_after__lte=expiry_end
        )

        for cert in expiring_certs:
            try:
                # TODO: Send notification
                logger.warning(
                    f"Certificate for {cert.user.username} expires in {days} days "
                    f"(Serial: {cert.serial_number})"
                )

                # TODO: Integrate with notifications app
                # from notifications.models import SystemNotification
                # SystemNotification.objects.create(
                #     user=cert.user,
                #     title=f'Certificate Expiring in {days} Days',
                #     message=f'Your certificate will expire on {cert.not_valid_after}. '
                #             f'It will be automatically renewed, but you may need to '
                #             f'download the new certificate from your profile.',
                #     level='warning' if days > 7 else 'error'
                # )

                warned_count += 1

            except Exception as e:
                logger.error(f"Failed to send expiry warning: {e}")

    logger.info(f"Sent {warned_count} certificate expiry warnings")
    return {'warned': warned_count}
