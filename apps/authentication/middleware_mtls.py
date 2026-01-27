"""
mTLS Authentication Middleware

Authentication Strategy:
1. Admin users (is_superuser=True): Password + MFA authentication
2. Regular users: Certificate + MFA authentication

Database Operations:
- SELECT FROM pki_certificate WHERE serial_number = ? AND is_revoked = FALSE
- SELECT FROM users_user WHERE id = certificate.user_id
- INSERT INTO django_session (via Django auth.login())

Flow:
1. nginx verifies client certificate (optional mode)
2. nginx passes cert info via headers:
   - X-SSL-Client-Verify: SUCCESS or FAILED or NONE
   - X-SSL-Client-Serial: Certificate serial number
   - X-SSL-Client-DN: Distinguished Name
3. Middleware checks authentication method:
   a) Admin user → Allow password auth (via /api/v1/authentication/tokens/)
   b) Regular user → Require valid certificate
4. If valid cert found → login user
5. All users (admin and regular) → MFA required (handled by MFARequiredMiddleware)
"""

from django.contrib.auth import login as auth_login
from django.utils.deprecation import MiddlewareMixin
from django.http import JsonResponse
from common.utils import get_logger

logger = get_logger(__file__)


class MTLSAuthenticationMiddleware(MiddlewareMixin):
    """
    Authenticate users via mTLS client certificates

    nginx must be configured to pass these headers:
    - X-SSL-Client-Verify: SUCCESS | FAILED | NONE
    - X-SSL-Client-Serial: hex serial number
    - X-SSL-Client-DN: Distinguished Name (CN=username)

    Note: Django admin (/admin/) allows traditional username/password auth
    for initial setup and certificate management.
    """

    # URLs that allow traditional authentication (username/password)
    TRADITIONAL_AUTH_URLS = [
        '/django-admin/',  # Django admin for emergency certificate management
        '/api/v1/authentication/auth/',  # Token creation endpoint
        '/api/v1/authentication/tokens/',  # Legacy token endpoint
    ]

    def process_request(self, request):
        """
        Process incoming request and authenticate via client certificate

        Database Queries:
        1. SELECT * FROM pki_certificate WHERE serial_number=? AND is_revoked=FALSE
        2. SELECT * FROM users_user WHERE id=certificate.user_id
        3. INSERT INTO django_session (via auth_login())
        """

        # Allow Django admin and auth endpoints to use traditional authentication
        for exempt_url in self.TRADITIONAL_AUTH_URLS:
            if request.path.startswith(exempt_url):
                # Mark that this is traditional auth, not certificate auth
                if request.user.is_authenticated:
                    request.session['auth_method'] = 'password'
                return None

        # Skip if user already authenticated via certificate
        if request.user.is_authenticated and request.session.get('auth_method') == 'certificate':
            return None

        # Get certificate info from nginx headers
        cert_verify = request.META.get('HTTP_X_SSL_CLIENT_VERIFY', 'NONE')
        cert_serial_hex = request.META.get('HTTP_X_SSL_CLIENT_SERIAL', '')
        cert_dn = request.META.get('HTTP_X_SSL_CLIENT_DN', '')

        # Skip if no certificate or verification failed
        if cert_verify != 'SUCCESS' or not cert_serial_hex:
            logger.debug(f"No valid client certificate: verify={cert_verify}, serial={cert_serial_hex}")
            return None

        # Convert hex serial to decimal (nginx sends hex, DB stores decimal)
        try:
            cert_serial = str(int(cert_serial_hex, 16))
        except ValueError:
            logger.warning(f"Invalid certificate serial format: {cert_serial_hex}")
            return None

        # Import here to avoid circular imports
        from pki.models import Certificate
        from django.contrib.auth import get_user_model

        User = get_user_model()

        try:
            # Query pki_certificate table
            # SQL: SELECT * FROM pki_certificate WHERE serial_number=%s AND revoked=FALSE
            certificate = Certificate.objects.select_related('user').get(
                serial_number=cert_serial,
                revoked=False
            )

            # Get the user associated with this certificate
            user = certificate.user

            # Check if user is active
            if not user.is_active:
                logger.warning(f"Certificate {cert_serial} (hex: {cert_serial_hex}) belongs to inactive user {user.username}")
                return JsonResponse({
                    'error': 'User account is disabled'
                }, status=403)

            # Log user in (creates session)
            # Database: INSERT INTO django_session
            auth_login(request, user, backend='django.contrib.auth.backends.ModelBackend')

            # Mark authentication method as certificate-based
            request.session['auth_method'] = 'certificate'

            logger.info(f"User {user.username} authenticated via mTLS certificate {cert_serial} (hex: {cert_serial_hex})")

            # Set MFA setup flag if user hasn't configured MFA yet
            # This tells MFARequiredMiddleware to redirect to /setup-mfa instead of /mfa-challenge
            if not user.otp_secret_key:
                request.session['mfa_setup_required'] = True
                logger.info(f"User {user.username} needs MFA setup")
            # DO NOT set auth_mfa here - user must verify MFA on each login

            return None

        except Certificate.DoesNotExist:
            logger.warning(f"Certificate with serial {cert_serial} (hex: {cert_serial_hex}) not found or revoked")
            return JsonResponse({
                'error': 'Invalid or revoked certificate'
            }, status=401)

        except Exception as e:
            logger.error(f"mTLS authentication error: {e}", exc_info=True)
            return JsonResponse({
                'error': 'Authentication error'
            }, status=500)


class MFARequiredMiddleware(MiddlewareMixin):
    """
    Enforce MFA verification for ALL authenticated users

    Blocks access to protected resources until MFA is verified.
    Both admin (password auth) and regular users (certificate auth) require MFA.
    """

    # URLs that don't require MFA verification
    MFA_EXEMPT_URLS = [
        '/api/v1/authentication/mfa/setup/',
        '/api/v1/authentication/mfa/verify-totp/',
        '/api/v1/authentication/mfa/status/',
        '/api/v1/authentication/auth/',  # Token creation
        '/api/v1/authentication/tokens/',  # Legacy tokens
        '/api/v1/users/me/',  # Current user profile
        '/api/v1/users/profile/',  # User profile
        '/api/health/',
        '/django-admin/',  # Django admin (for emergency certificate management)
        '/setup-mfa',
        '/mfa-challenge',
        '/admin',  # React admin login page (NOT Django admin)
        '/static/',
        '/media/',
    ]

    def process_request(self, request):
        """
        Check if user has completed MFA verification

        Database: Reads request.session (django_session table)

        MFA is now REQUIRED for:
        - Admin users (password auth)
        - Regular users (certificate auth)
        """

        # Skip if user not authenticated
        if not request.user.is_authenticated:
            return None

        # NOTE: MFA is now required for BOTH password and certificate auth
        # Previously only certificate auth required MFA, but now admin password auth also requires it

        # Check if URL is exempt from MFA requirement
        for exempt_url in self.MFA_EXEMPT_URLS:
            if request.path.startswith(exempt_url):
                return None

        # Check if user needs MFA setup
        if request.session.get('mfa_setup_required'):
            # Allow access to setup page, block everything else
            if not request.path.startswith('/setup-mfa'):
                return JsonResponse({
                    'error': 'MFA setup required',
                    'redirect': '/setup-mfa'
                }, status=403)
            return None

        # Check if MFA is verified for this session (using JumpServer's standard session key)
        if not request.session.get('auth_mfa'):
            # Allow access to MFA challenge page, block everything else
            if not request.path.startswith('/mfa-challenge'):
                return JsonResponse({
                    'error': 'MFA verification required',
                    'redirect': '/mfa-challenge'
                }, status=403)
            return None

        # MFA verified, allow access
        return None
