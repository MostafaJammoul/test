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
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.conf import settings
from django.utils import timezone
from django.contrib.auth import get_user_model

User = get_user_model()


class MFASetupView(APIView):
    """
    Generate TOTP secret and QR code for MFA enrollment

    GET: Returns QR code and secret for user to scan
    POST: Verifies TOTP code and saves secret to user account

    Note: Allows unauthenticated access during login flow (uses session data)
    """
    permission_classes = [AllowAny]
    # Don't disable authentication - we need to see middleware-authenticated users

    def get(self, request):
        """
        Generate TOTP secret and QR code

        Database: No writes, only reads users_user to check current mfa_level
        """
        # Check if user is authenticated (middleware or DRF) OR has username in session
        if request.user.is_authenticated and not request.user.is_anonymous:
            user = request.user
        elif 'auth_username' in request.session:
            # User logged in but hasn't completed MFA yet
            username = request.session.get('auth_username')
            try:
                user = User.objects.get(username=username)
            except User.DoesNotExist:
                return Response({
                    'error': 'Session expired, please login again'
                }, status=status.HTTP_401_UNAUTHORIZED)
        else:
            return Response({
                'error': 'Authentication required'
            }, status=status.HTTP_401_UNAUTHORIZED)

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
        # Check if user is authenticated (middleware or DRF) OR has username in session
        if request.user.is_authenticated and not request.user.is_anonymous:
            user = request.user
        elif 'auth_username' in request.session:
            username = request.session.get('auth_username')
            try:
                user = User.objects.get(username=username)
            except User.DoesNotExist:
                return Response({
                    'error': 'Session expired, please login again'
                }, status=status.HTTP_401_UNAUTHORIZED)
        else:
            return Response({
                'error': 'Authentication required'
            }, status=status.HTTP_401_UNAUTHORIZED)

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

        # Authenticate user in Django session
        from django.contrib.auth import login as auth_login
        auth_login(request, user, backend='django.contrib.auth.backends.ModelBackend')

        # Mark MFA as verified in session using JumpServer's standard keys
        import time
        request.session['auth_mfa'] = 1
        request.session['auth_mfa_username'] = user.username
        request.session['auth_mfa_time'] = time.time()
        request.session['auth_mfa_required'] = 0
        request.session['auth_mfa_type'] = 'totp'

        # Clear pending secret
        del request.session['pending_mfa_secret']

        # Generate authentication token for immediate use
        token, date_expired = user.create_bearer_token(request)

        # Update last login (already set by auth_login, but ensure it's saved)
        user.last_login = timezone.now()
        user.save(update_fields=['last_login'])

        # Import user serializer for response
        from users.serializers import UserProfileSerializer

        return Response({
            'success': True,
            'message': 'MFA configured successfully',
            'token': token,
            'keyword': 'Bearer',
            'date_expired': date_expired.strftime('%Y/%m/%d %H:%M:%S %z'),
            'user': UserProfileSerializer(user).data
        })


class MFAVerifyView(APIView):
    """
    Verify MFA code during login

    Database: Reads users_user.otp_secret_key, writes to django_session

    Note: Allows unauthenticated access during login flow (uses session data)
    """
    permission_classes = [AllowAny]
    # Don't disable authentication - we need to see middleware-authenticated users

    def post(self, request):
        """
        Verify TOTP code for authentication

        Database: Only reads users_user.otp_secret_key
        Session: Sets mfa_verified=True in django_session
        """
        # Check if user is authenticated (middleware or DRF) OR has username in session
        if request.user.is_authenticated and not request.user.is_anonymous:
            user = request.user
        elif 'auth_username' in request.session:
            username = request.session.get('auth_username')
            try:
                user = User.objects.get(username=username)
            except User.DoesNotExist:
                return Response({
                    'error': 'Session expired, please login again'
                }, status=status.HTTP_401_UNAUTHORIZED)
        else:
            return Response({
                'error': 'Authentication required'
            }, status=status.HTTP_401_UNAUTHORIZED)

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

        # Authenticate user in Django session
        from django.contrib.auth import login as auth_login
        auth_login(request, user, backend='django.contrib.auth.backends.ModelBackend')

        # Mark MFA as verified in session using JumpServer's standard keys
        # Database Write: django_session table
        import time
        request.session['auth_mfa'] = 1
        request.session['auth_mfa_username'] = user.username
        request.session['auth_mfa_time'] = time.time()
        request.session['auth_mfa_required'] = 0
        request.session['auth_mfa_type'] = 'totp'

        # Generate authentication token for immediate use
        token, date_expired = user.create_bearer_token(request)

        # Update last login (already set by auth_login, but ensure it's saved)
        user.last_login = timezone.now()
        user.save(update_fields=['last_login'])

        # Import user serializer for response
        from users.serializers import UserProfileSerializer

        return Response({
            'success': True,
            'message': 'MFA verification successful',
            'token': token,
            'keyword': 'Bearer',
            'date_expired': date_expired.strftime('%Y/%m/%d %H:%M:%S %z'),
            'user': UserProfileSerializer(user).data
        })


class MFAStatusView(APIView):
    """
    Check if user has MFA configured and if current session is MFA-verified

    Database: Only reads users_user.mfa_level, users_user.otp_secret_key

    Note: Allows unauthenticated access during login flow (uses session data)
    """
    permission_classes = [AllowAny]
    # Don't disable authentication - we need to see middleware-authenticated users

    def get(self, request):
        # Check if user is authenticated (either by middleware or DRF) OR has username in session
        if request.user.is_authenticated and not request.user.is_anonymous:
            user = request.user
        elif 'auth_username' in request.session:
            username = request.session.get('auth_username')
            try:
                user = User.objects.get(username=username)
            except User.DoesNotExist:
                return Response({
                    'error': 'Session expired, please login again'
                }, status=status.HTTP_401_UNAUTHORIZED)
        else:
            return Response({
                'error': 'Authentication required',
                'mfa_configured': False,
                'mfa_required': False,
                'mfa_verified': False,
                'needs_setup': False
            }, status=status.HTTP_401_UNAUTHORIZED)

        auth_method = request.session.get('auth_method', 'unknown')

        # MFA is now REQUIRED for ALL users (both password and certificate auth)
        mfa_configured = user.mfa_level > 0 and bool(user.otp_secret_key)
        # Check JumpServer's standard MFA session key
        mfa_verified = bool(request.session.get('auth_mfa') and
                           request.session.get('auth_mfa_username') == user.username)
        needs_setup = not mfa_configured

        return Response({
            'auth_method': auth_method,
            'mfa_configured': mfa_configured,
            'mfa_required': True,  # Required for ALL users
            'mfa_verified': mfa_verified,
            'needs_setup': needs_setup
        })
