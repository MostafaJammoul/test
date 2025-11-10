"""
MFA Setup/Enrollment API

Allows users to configure TOTP (Google Authenticator/Authy) on first login.

Database Operations:
- Reads: users_user (check if mfa already setup)
- Writes: users_user.otp_secret_key, users_user.mfa_level

Flow:
1. GET /mfa/setup/ - Generate QR code, return secret
2. POST /mfa/setup/ - Verify code, save secret to user
"""

import pyotp
import qrcode
import base64
from io import BytesIO
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.conf import settings
from django.utils import timezone


class MFASetupView(APIView):
    """
    Generate TOTP secret and QR code for MFA enrollment

    GET: Returns QR code and secret for user to scan
    POST: Verifies TOTP code and saves secret to user account
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """
        Generate TOTP secret and QR code

        Database: No writes, only reads users_user to check current mfa_level
        """
        user = request.user

        # Check if MFA already configured
        if user.mfa_level > 0 and user.otp_secret_key:
            return Response({
                'error': 'MFA already configured for this user',
                'configured': True
            }, status=status.HTTP_400_BAD_REQUEST)

        # Generate new TOTP secret
        secret = pyotp.random_base32()

        # Create TOTP URI for QR code
        totp_uri = pyotp.totp.TOTP(secret).provisioning_uri(
            name=user.username,
            issuer_name=settings.SITE_URL or 'JumpServer Blockchain'
        )

        # Generate QR code
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(totp_uri)
        qr.make(fit=True)

        img = qr.make_image(fill_color="black", back_color="white")

        # Convert QR code to base64
        buffer = BytesIO()
        img.save(buffer, format='PNG')
        buffer.seek(0)
        qr_code_base64 = base64.b64encode(buffer.getvalue()).decode()

        # Store secret temporarily in session (not in DB yet)
        request.session['pending_mfa_secret'] = secret

        return Response({
            'secret': secret,
            'qr_code': f'data:image/png;base64,{qr_code_base64}',
            'instructions': 'Scan this QR code with Google Authenticator or Authy'
        })

    def post(self, request):
        """
        Verify TOTP code and enable MFA

        Database Writes:
        - users_user.otp_secret_key = secret
        - users_user.mfa_level = 2 (force enabled)
        """
        user = request.user
        code = request.data.get('code')

        if not code:
            return Response({
                'error': 'MFA code is required'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Get pending secret from session
        secret = request.session.get('pending_mfa_secret')

        if not secret:
            return Response({
                'error': 'No pending MFA setup. Please start setup again.'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Verify TOTP code
        totp = pyotp.TOTP(secret)
        if not totp.verify(code, valid_window=1):
            return Response({
                'error': 'Invalid MFA code. Please try again.'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Save secret to user and enable MFA
        # Database Transaction Start
        user.otp_secret_key = secret
        user.mfa_level = 2  # Force enabled for all blockchain users
        user.save(update_fields=['otp_secret_key', 'mfa_level'])
        # Database Transaction End

        # Clear session
        del request.session['pending_mfa_secret']

        return Response({
            'success': True,
            'message': 'MFA configured successfully'
        })


class MFAVerifyView(APIView):
    """
    Verify MFA code during login

    Database: Reads users_user.otp_secret_key, writes to django_session
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        """
        Verify TOTP code for authentication

        Database: Only reads users_user.otp_secret_key
        Session: Sets mfa_verified=True in django_session
        """
        user = request.user
        code = request.data.get('code')

        if not code:
            return Response({
                'error': 'MFA code is required'
            }, status=status.HTTP_400_BAD_REQUEST)

        if not user.otp_secret_key:
            return Response({
                'error': 'MFA not configured for this user'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Verify TOTP code
        totp = pyotp.TOTP(user.otp_secret_key)
        if not totp.verify(code, valid_window=1):
            return Response({
                'error': 'Invalid MFA code'
            }, status=status.HTTP_401_UNAUTHORIZED)

        # Mark MFA as verified in session
        # Database Write: django_session table
        request.session['mfa_verified'] = True
        request.session['mfa_verified_at'] = str(timezone.now())

        return Response({
            'success': True,
            'message': 'MFA verification successful'
        })


class MFAStatusView(APIView):
    """
    Check if user has MFA configured and if current session is MFA-verified

    Database: Only reads users_user.mfa_level, users_user.otp_secret_key

    Note: If user is authenticated via password (not certificate), MFA is not required.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        auth_method = request.session.get('auth_method', 'unknown')

        # If using traditional authentication (not certificate), MFA is optional
        if auth_method != 'certificate':
            return Response({
                'auth_method': auth_method,
                'mfa_configured': user.mfa_level > 0 and bool(user.otp_secret_key),
                'mfa_required': False,  # Not required for password auth
                'mfa_verified': True,  # Already authenticated
                'needs_setup': False  # No setup needed for password auth
            })

        # Certificate-based authentication requires MFA
        return Response({
            'auth_method': 'certificate',
            'mfa_configured': user.mfa_level > 0 and bool(user.otp_secret_key),
            'mfa_required': True,
            'mfa_verified': request.session.get('mfa_verified', False),
            'needs_setup': user.mfa_level == 0 or not user.otp_secret_key
        })
