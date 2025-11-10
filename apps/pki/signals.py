"""
PKI Signal Handlers

Auto-generate certificate when user is created

Database Operations:
- Triggered by: INSERT INTO users_user
- Executes: Certificate generation (calls issue_user_cert logic)
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth import get_user_model
from pki.models import CertificateAuthority, Certificate
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
from datetime import datetime, timedelta
import logging

User = get_user_model()
logger = logging.getLogger(__name__)


@receiver(post_save, sender=User)
def auto_generate_certificate(sender, instance, created, **kwargs):
    """
    Auto-generate mTLS certificate when new user is created
    
    Database: INSERT INTO pki_certificate
    """
    if not created:
        # Only for new users
        return
    
    # Check if user already has a certificate
    if Certificate.objects.filter(user=instance, revoked=False).exists():
        return
    
    try:
        # Get active CA
        ca = CertificateAuthority.objects.filter(is_active=True).first()
        if not ca:
            logger.warning(f"No active CA found. Cannot generate certificate for {instance.username}")
            return
        
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
            x509.NameAttribute(NameOID.COMMON_NAME, instance.username),
        ])
        
        not_before = datetime.utcnow()
        not_after = not_before + timedelta(days=365)
        
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
            user=instance,
            cert_type='user',
            serial_number=str(serial_number),
            certificate=cert.public_bytes(serialization.Encoding.PEM).decode(),
            private_key=user_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption()
            ).decode(),
            subject_dn=f"CN={instance.username},O=JumpServer Blockchain,C=PS",
            issuer_dn=f"CN=JumpServer Root CA,O=JumpServer Blockchain,C=PS",
            not_before=not_before,
            not_after=not_after
        )
        
        logger.info(f"Auto-generated certificate for user {instance.username}: {cert_obj.id}")
        
    except Exception as e:
        logger.error(f"Failed to auto-generate certificate for {instance.username}: {e}", exc_info=True)
