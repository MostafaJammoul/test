#!/bin/bash
set -e

echo "========================================="
echo "COMPREHENSIVE AUTHENTICATION DIAGNOSIS"
echo "========================================="
echo ""

cd "$(dirname "$0")/backend"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "1. ADMIN USER STATUS"
echo "========================================="
python manage.py shell <<'PYTHON'
from django.contrib.auth import get_user_model
User = get_user_model()

try:
    admin = User.objects.get(username='admin')
    print(f"✓ Username: {admin.username}")
    print(f"✓ is_superuser: {admin.is_superuser}")
    print(f"✓ is_staff: {admin.is_staff}")
    print(f"✓ is_active: {admin.is_active}")
    print(f"✓ Password check: {admin.check_password('admin')}")
    print(f"✓ mfa_enabled: {admin.mfa_enabled}")
    print(f"✓ otp_secret_key: {'SET' if admin.otp_secret_key else 'NOT SET'}")
except Exception as e:
    print(f"✗ Error: {e}")
PYTHON

echo ""
echo "========================================="
echo "2. DJANGO SETTINGS CHECK"
echo "========================================="
python manage.py shell <<'PYTHON'
from django.conf import settings

print(f"DEBUG: {settings.DEBUG}")
print(f"ALLOWED_HOSTS: {settings.ALLOWED_HOSTS}")
print(f"SESSION_COOKIE_NAME: {settings.SESSION_COOKIE_NAME}")
print(f"CSRF_COOKIE_NAME: {settings.CSRF_COOKIE_NAME}")
print(f"CSRF_USE_SESSIONS: {getattr(settings, 'CSRF_USE_SESSIONS', False)}")
print(f"CSRF_COOKIE_HTTPONLY: {getattr(settings, 'CSRF_COOKIE_HTTPONLY', False)}")
print(f"CSRF_COOKIE_SECURE: {settings.CSRF_COOKIE_SECURE}")
print(f"SESSION_COOKIE_SECURE: {settings.SESSION_COOKIE_SECURE}")
print(f"CORS_ALLOW_CREDENTIALS: {getattr(settings, 'CORS_ALLOW_CREDENTIALS', False)}")

print("\nCSRF_TRUSTED_ORIGINS:")
for origin in settings.CSRF_TRUSTED_ORIGINS[:10]:  # First 10
    print(f"  - {origin}")

print("\nCORS_ALLOWED_ORIGINS:")
for origin in getattr(settings, 'CORS_ALLOWED_ORIGINS', [])[:10]:  # First 10
    print(f"  - {origin}")
PYTHON

echo ""
echo "========================================="
echo "3. AUTHENTICATION BACKEND CHECK"
echo "========================================="
python manage.py shell <<'PYTHON'
from django.conf import settings

print("AUTHENTICATION_BACKENDS:")
for backend in settings.AUTHENTICATION_BACKENDS:
    print(f"  - {backend}")
PYTHON

echo ""
echo "========================================="
echo "4. MIDDLEWARE CONFIGURATION"
echo "========================================="
python manage.py shell <<'PYTHON'
from django.conf import settings

print("MIDDLEWARE (in order):")
for i, middleware in enumerate(settings.MIDDLEWARE, 1):
    print(f"{i:2d}. {middleware}")
PYTHON

echo ""
echo "========================================="
echo "5. TOKEN ENDPOINT CONFIGURATION"
echo "========================================="
python manage.py shell <<'PYTHON'
from apps.authentication.api.token import TokenCreateApi

view = TokenCreateApi()
print(f"View class: {view.__class__.__name__}")
print(f"Permission classes: {view.permission_classes}")
print(f"Serializer class: {view.serializer_class}")

# Check if csrf_exempt
import inspect
print(f"\nView methods:")
for name, method in inspect.getmembers(view, predicate=inspect.ismethod):
    if not name.startswith('_'):
        csrf_exempt = getattr(method, 'csrf_exempt', False)
        if csrf_exempt:
            print(f"  {name}: CSRF_EXEMPT")
PYTHON

echo ""
echo "========================================="
echo "6. DIRECT CURL TEST (NO CSRF)"
echo "========================================="
response=$(curl -s -w "\nHTTP_CODE:%{http_code}\nCONTENT_TYPE:%{content_type}" \
  -X POST http://localhost:8080/api/v1/authentication/tokens/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}')

http_code=$(echo "$response" | grep "HTTP_CODE" | cut -d: -f2)
content_type=$(echo "$response" | grep "CONTENT_TYPE" | cut -d: -f2)
body=$(echo "$response" | sed '/HTTP_CODE/d' | sed '/CONTENT_TYPE/d')

echo "HTTP Status: $http_code"
echo "Content-Type: $content_type"
echo "Response Body:"
echo "$body" | python -m json.tool 2>/dev/null || echo "$body"

echo ""
echo "========================================="
echo "7. CURL TEST WITH CSRF TOKEN"
echo "========================================="
# First get CSRF token
echo "Step 1: Getting CSRF token..."
cookie_jar=$(mktemp)
csrf_response=$(curl -s -c "$cookie_jar" -w "\nHTTP_CODE:%{http_code}" \
  http://localhost:8080/api/v1/authentication/mfa/status/)

csrf_http_code=$(echo "$csrf_response" | grep "HTTP_CODE" | cut -d: -f2)
echo "CSRF fetch status: $csrf_http_code"

# Extract CSRF token from cookie
csrf_token=$(grep 'jms_csrftoken' "$cookie_jar" | awk '{print $7}')
echo "CSRF Token: ${csrf_token:-NOT FOUND}"

# Try login with CSRF token
echo ""
echo "Step 2: Login with CSRF token..."
login_response=$(curl -s -b "$cookie_jar" -w "\nHTTP_CODE:%{http_code}" \
  -X POST http://localhost:8080/api/v1/authentication/tokens/ \
  -H "Content-Type: application/json" \
  -H "X-CSRFToken: $csrf_token" \
  -H "Referer: http://localhost:8080/" \
  -d '{"username":"admin","password":"admin"}')

login_http_code=$(echo "$login_response" | grep "HTTP_CODE" | cut -d: -f2)
login_body=$(echo "$login_response" | sed '/HTTP_CODE/d')

echo "HTTP Status: $login_http_code"
echo "Response Body:"
echo "$login_body" | python -m json.tool 2>/dev/null || echo "$login_body"

rm -f "$cookie_jar"

echo ""
echo "========================================="
echo "8. REST FRAMEWORK SETTINGS"
echo "========================================="
python manage.py shell <<'PYTHON'
from django.conf import settings

rf_settings = settings.REST_FRAMEWORK
print("REST_FRAMEWORK settings:")
print(f"  DEFAULT_AUTHENTICATION_CLASSES:")
for cls in rf_settings.get('DEFAULT_AUTHENTICATION_CLASSES', []):
    print(f"    - {cls}")
print(f"  DEFAULT_PERMISSION_CLASSES:")
for cls in rf_settings.get('DEFAULT_PERMISSION_CLASSES', []):
    print(f"    - {cls}")
print(f"  DEFAULT_RENDERER_CLASSES:")
for cls in rf_settings.get('DEFAULT_RENDERER_CLASSES', []):
    print(f"    - {cls}")
PYTHON

echo ""
echo "========================================="
echo "9. URL PATTERN CHECK"
echo "========================================="
python manage.py shell <<'PYTHON'
from django.urls import resolve
from django.urls.exceptions import Resolver404

try:
    match = resolve('/api/v1/authentication/tokens/')
    print(f"✓ URL resolves to: {match.func.__module__}.{match.func.__name__}")
    print(f"  View class: {match.func.cls if hasattr(match.func, 'cls') else 'N/A'}")
    print(f"  URL name: {match.url_name}")
    print(f"  Namespace: {match.namespace}")
except Resolver404:
    print("✗ URL does not resolve!")
PYTHON

echo ""
echo "========================================="
echo "10. CHECK FOR CUSTOM PERMISSIONS"
echo "========================================="
python manage.py shell <<'PYTHON'
from apps.authentication.api.token import TokenCreateApi
from rest_framework.request import Request
from django.test import RequestFactory

view = TokenCreateApi()
factory = RequestFactory()

# Create a mock request
request = factory.post('/api/v1/authentication/tokens/')
request.session = {}

# Check permissions
print("Checking permission classes...")
for perm_class in view.permission_classes:
    perm = perm_class()
    print(f"  - {perm_class.__name__}: ", end='')
    try:
        # AllowAny always returns True
        result = perm.has_permission(request, view)
        print(f"{'✓ ALLOWED' if result else '✗ DENIED'}")
    except Exception as e:
        print(f"✗ ERROR: {e}")
PYTHON

echo ""
echo "========================================="
echo "11. SETTINGS FROM DATABASE"
echo "========================================="
python manage.py shell <<'PYTHON'
try:
    from settings.models import Setting

    security_settings = Setting.objects.filter(name__contains='SECURITY')
    if security_settings.exists():
        print("Security-related settings:")
        for setting in security_settings:
            print(f"  {setting.name}: {setting.value}")
    else:
        print("No security settings found in database")
except Exception as e:
    print(f"Settings model not available or error: {e}")
PYTHON

echo ""
echo "========================================="
echo "12. CHECK MFA SETTINGS"
echo "========================================="
python manage.py shell <<'PYTHON'
from django.conf import settings

mfa_settings = [
    'SECURITY_MFA_AUTH',
    'SECURITY_MFA_AUTH_ENABLED',
    'SECURITY_MFA_AUTH_ENABLED_FOR_THIRD_PARTY',
    'SECURITY_MFA_IN_LOGIN_PAGE',
]

print("MFA Configuration:")
for setting_name in mfa_settings:
    value = getattr(settings, setting_name, 'NOT SET')
    print(f"  {setting_name}: {value}")
PYTHON

echo ""
echo "========================================="
echo "13. TEST AUTHENTICATION DIRECTLY"
echo "========================================="
python manage.py shell <<'PYTHON'
from django.contrib.auth import authenticate
from django.test import RequestFactory

factory = RequestFactory()
request = factory.post('/api/v1/authentication/tokens/')
request.session = {}

print("Testing authenticate() function...")
user = authenticate(request, username='admin', password='admin')

if user:
    print(f"✓ Authentication SUCCESSFUL")
    print(f"  User: {user.username}")
    print(f"  ID: {user.id}")
    print(f"  Backend: {getattr(user, 'backend', 'NOT SET')}")
else:
    print(f"✗ Authentication FAILED")
    error_msg = getattr(request, 'error_message', None)
    if error_msg:
        print(f"  Error: {error_msg}")
PYTHON

echo ""
echo "========================================="
echo "14. CHECK REFERER MIDDLEWARE"
echo "========================================="
python manage.py shell <<'PYTHON'
try:
    from jumpserver.middleware import RefererCheckMiddleware
    import inspect

    print("RefererCheckMiddleware exists")
    print("Source file:", inspect.getfile(RefererCheckMiddleware))

    # Check if it has exemption logic
    if hasattr(RefererCheckMiddleware, 'process_request'):
        print("Has process_request method")
    if hasattr(RefererCheckMiddleware, 'process_view'):
        print("Has process_view method")

except Exception as e:
    print(f"RefererCheckMiddleware check failed: {e}")
PYTHON

echo ""
echo "========================================="
echo "15. SIMULATE BROWSER REQUEST"
echo "========================================="
python manage.py shell <<'PYTHON'
from django.test import RequestFactory, Client
from apps.authentication.api.token import TokenCreateApi
import json

# Create a test client
client = Client()

print("Simulating browser POST request...")
response = client.post(
    '/api/v1/authentication/tokens/',
    data=json.dumps({'username': 'admin', 'password': 'admin'}),
    content_type='application/json',
    HTTP_ORIGIN='http://192.168.148.154:3000',
    HTTP_REFERER='http://192.168.148.154:3000/admin',
)

print(f"Status Code: {response.status_code}")
print(f"Content-Type: {response.get('Content-Type', 'NOT SET')}")
print(f"Response Length: {len(response.content)} bytes")
print(f"Response Body: {response.content.decode('utf-8')[:500]}")

# Check if CSRF was the issue
if response.status_code == 403:
    print("\n✗ 403 FORBIDDEN - Likely CSRF issue")
elif response.status_code == 401:
    print("\n✗ 401 UNAUTHORIZED - Check authentication/permissions")
elif response.status_code == 200:
    print("\n✓ 200 OK - Request successful!")
PYTHON

echo ""
echo "========================================="
echo "DIAGNOSIS COMPLETE"
echo "========================================="
