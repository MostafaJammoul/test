# -*- coding: utf-8 -*-
#
"""
Certificate Authority Manager
Handles certificate generation, signing, and revocation
"""
import datetime
from cryptography import x509
from cryptography.x509.oid import NameOID, ExtensionOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
from django.utils import timezone

from .models import CertificateAuthority, Certificate, CertificateRevocationList


class CAManager:
    """Manager for Certificate Authority operations"""

    @staticmethod
    def create_ca(name, validity_days=3650):
        """
        Create a new Certificate Authority

        Args:
            name: CA name
            validity_days: Certificate validity period (default 10 years)

        Returns:
            CertificateAuthority instance
        """
        # Generate RSA key pair
        private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=4096,
            backend=default_backend()
        )

        # Create CA certificate
        subject = issuer = x509.Name([
            x509.NameAttribute(NameOID.COUNTRY_NAME, "US"),
            x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, "State"),
            x509.NameAttribute(NameOID.LOCALITY_NAME, "City"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Chain of Custody CA"),
            x509.NameAttribute(NameOID.COMMON_NAME, name),
        ])

        now = datetime.datetime.utcnow()
        cert = (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(issuer)
            .public_key(private_key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now)
            .not_valid_after(now + datetime.timedelta(days=validity_days))
            .add_extension(
                x509.BasicConstraints(ca=True, path_length=0),
                critical=True,
            )
            .add_extension(
                x509.KeyUsage(
                    digital_signature=True,
                    key_cert_sign=True,
                    crl_sign=True,
                    key_encipherment=False,
                    content_commitment=False,
                    data_encipherment=False,
                    key_agreement=False,
                    encipher_only=False,
                    decipher_only=False,
                ),
                critical=True,
            )
            .sign(private_key, hashes.SHA256(), default_backend())
        )

        # Serialize to PEM
        cert_pem = cert.public_bytes(serialization.Encoding.PEM).decode('utf-8')
        key_pem = private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        ).decode('utf-8')

        # Save to database
        ca = CertificateAuthority.objects.create(
            name=name,
            certificate=cert_pem,
            private_key=key_pem,
            serial_number=1,
            valid_from=timezone.make_aware(now),
            valid_until=timezone.make_aware(now + datetime.timedelta(days=validity_days))
        )

        return ca

    @staticmethod
    def issue_user_certificate(ca, user, validity_days=365):
        """
        Issue a client certificate for a user

        Args:
            ca: CertificateAuthority instance
            user: User instance
            validity_days: Certificate validity (default 1 year)

        Returns:
            Certificate instance with certificate and private key
        """
        # Load CA certificate and key
        ca_cert = x509.load_pem_x509_certificate(
            ca.certificate.encode('utf-8'),
            default_backend()
        )
        ca_key = serialization.load_pem_private_key(
            ca.private_key.encode('utf-8'),
            password=None,
            backend=default_backend()
        )

        # Generate user key pair
        user_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048,
            backend=default_backend()
        )

        # Create user certificate
        subject = x509.Name([
            x509.NameAttribute(NameOID.COUNTRY_NAME, "US"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Chain of Custody"),
            x509.NameAttribute(NameOID.COMMON_NAME, user.username),
            x509.NameAttribute(NameOID.EMAIL_ADDRESS, user.email),
        ])

        now = datetime.datetime.utcnow()
        serial = ca.serial_number
        ca.serial_number += 1
        ca.save(update_fields=['serial_number'])

        cert = (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(ca_cert.subject)
            .public_key(user_key.public_key())
            .serial_number(serial)
            .not_valid_before(now)
            .not_valid_after(now + datetime.timedelta(days=validity_days))
            .add_extension(
                x509.BasicConstraints(ca=False, path_length=None),
                critical=True,
            )
            .add_extension(
                x509.KeyUsage(
                    digital_signature=True,
                    key_encipherment=True,
                    key_cert_sign=False,
                    crl_sign=False,
                    content_commitment=False,
                    data_encipherment=False,
                    key_agreement=False,
                    encipher_only=False,
                    decipher_only=False,
                ),
                critical=True,
            )
            .add_extension(
                x509.ExtendedKeyUsage([
                    x509.oid.ExtendedKeyUsageOID.CLIENT_AUTH,
                ]),
                critical=True,
            )
            .sign(ca_key, hashes.SHA256(), default_backend())
        )

        # Serialize to PEM
        cert_pem = cert.public_bytes(serialization.Encoding.PEM).decode('utf-8')
        key_pem = user_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        ).decode('utf-8')

        # Save to database
        certificate = Certificate.objects.create(
            ca=ca,
            user=user,
            cert_type='user',
            serial_number=str(serial),
            certificate=cert_pem,
            private_key=key_pem,
            subject_dn=subject.rfc4514_string(),
            issuer_dn=ca_cert.subject.rfc4514_string(),
            not_before=timezone.make_aware(now),
            not_after=timezone.make_aware(now + datetime.timedelta(days=validity_days))
        )

        return certificate

    @staticmethod
    def verify_certificate(cert_pem, ca):
        """
        Verify a certificate against a CA

        Args:
            cert_pem: Certificate in PEM format
            ca: CertificateAuthority instance

        Returns:
            (is_valid, error_message)
        """
        try:
            cert = x509.load_pem_x509_certificate(
                cert_pem.encode('utf-8'),
                default_backend()
            )
            ca_cert = x509.load_pem_x509_certificate(
                ca.certificate.encode('utf-8'),
                default_backend()
            )
            ca_public_key = ca_cert.public_key()

            # Verify signature
            ca_public_key.verify(
                cert.signature,
                cert.tbs_certificate_bytes,
                cert.signature_algorithm_parameters,
                cert.signature_hash_algorithm
            )

            # Check validity period
            now = datetime.datetime.utcnow()
            if now < cert.not_valid_before:
                return False, "Certificate not yet valid"
            if now > cert.not_valid_after:
                return False, "Certificate expired"

            # Check if revoked
            serial = str(cert.serial_number)
            revoked = Certificate.objects.filter(
                serial_number=serial,
                revoked=True
            ).exists()
            if revoked:
                return False, "Certificate revoked"

            return True, None

        except Exception as e:
            return False, str(e)

    @staticmethod
    def export_pkcs12(certificate_pem, private_key_pem, ca_cert_pem, password=b''):
        """
        Export certificate and private key as PKCS#12 (.p12) format

        Args:
            certificate_pem: User certificate in PEM format
            private_key_pem: User private key in PEM format
            ca_cert_pem: CA certificate in PEM format
            password: Password to encrypt .p12 file (bytes)

        Returns:
            PKCS#12 data (bytes)
        """
        from cryptography.hazmat.primitives.serialization import pkcs12

        # Load certificate
        cert = x509.load_pem_x509_certificate(
            certificate_pem.encode('utf-8'),
            default_backend()
        )

        # Load private key
        private_key = serialization.load_pem_private_key(
            private_key_pem.encode('utf-8'),
            password=None,
            backend=default_backend()
        )

        # Load CA certificate
        ca_cert = x509.load_pem_x509_certificate(
            ca_cert_pem.encode('utf-8'),
            default_backend()
        )

        # Create PKCS#12
        p12_data = pkcs12.serialize_key_and_certificates(
            name=b"User Certificate",
            key=private_key,
            cert=cert,
            cas=[ca_cert],
            encryption_algorithm=serialization.BestAvailableEncryption(password) if password else serialization.NoEncryption()
        )

        return p12_data

    @staticmethod
    def generate_crl(ca):
        """
        Generate Certificate Revocation List

        Args:
            ca: CertificateAuthority instance

        Returns:
            CertificateRevocationList instance
        """
        # Load CA certificate and key
        ca_cert = x509.load_pem_x509_certificate(
            ca.certificate.encode('utf-8'),
            default_backend()
        )
        ca_key = serialization.load_pem_private_key(
            ca.private_key.encode('utf-8'),
            password=None,
            backend=default_backend()
        )

        # Get revoked certificates
        revoked_certs = Certificate.objects.filter(ca=ca, revoked=True)

        builder = x509.CertificateRevocationListBuilder()
        builder = builder.issuer_name(ca_cert.subject)

        now = datetime.datetime.utcnow()
        builder = builder.last_update(now)
        builder = builder.next_update(now + datetime.timedelta(days=7))

        # Add revoked certificates
        for cert in revoked_certs:
            revoked_cert = (
                x509.RevokedCertificateBuilder()
                .serial_number(int(cert.serial_number))
                .revocation_date(cert.revocation_date)
                .build(default_backend())
            )
            builder = builder.add_revoked_certificate(revoked_cert)

        # Sign CRL
        crl = builder.sign(
            private_key=ca_key,
            algorithm=hashes.SHA256(),
            backend=default_backend()
        )

        # Serialize to PEM
        crl_pem = crl.public_bytes(serialization.Encoding.PEM).decode('utf-8')

        # Save to database
        crl_obj = CertificateRevocationList.objects.create(
            ca=ca,
            crl_pem=crl_pem,
            this_update=timezone.make_aware(now),
            next_update=timezone.make_aware(now + datetime.timedelta(days=7))
        )

        return crl_obj
