#!/usr/bin/env python
"""
Direct login test - bypasses middleware to test authentication logic
"""
import os
import sys
import django

# Add apps directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'apps'))

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'jumpserver.settings')
django.setup()

from django.contrib.auth import get_user_model, authenticate
from django.test import RequestFactory
from authentication.api.token import TokenCreateApi
from authentication.serializers import BearerTokenSerializer

User = get_user_model()

print("=" * 60)
print("ADMIN LOGIN DIAGNOSTIC TEST")
print("=" * 60)

# 1. Check if admin user exists
print("\n1. Checking admin user...")
try:
    admin = User.objects.get(username='admin')
    print(f"   ✓ Admin user found: {admin.username}")
    print(f"   - ID: {admin.id}")
    print(f"   - is_superuser: {admin.is_superuser}")
    print(f"   - is_active: {admin.is_active}")
    print(f"   - is_staff: {admin.is_staff}")
    print(f"   - mfa_level: {admin.mfa_level}")
    print(f"   - otp_secret_key: {bool(admin.otp_secret_key)}")
    print(f"   - mfa_enabled: {admin.mfa_enabled}")
except User.DoesNotExist:
    print("   ✗ Admin user NOT FOUND!")
    sys.exit(1)

# 2. Test password authentication
print("\n2. Testing password authentication...")
from django.contrib.auth.hashers import check_password
if check_password('admin', admin.password):
    print("   ✓ Password 'admin' is correct")
else:
    print("   ✗ Password 'admin' does NOT match!")
    print("   Trying to reset password...")
    admin.set_password('admin')
    admin.save()
    print("   ✓ Password reset to 'admin'")

# 3. Test Django authenticate()
print("\n3. Testing Django authenticate()...")
factory = RequestFactory()
request = factory.post('/api/v1/authentication/tokens/')
request.session = {}

user = authenticate(request, username='admin', password='admin')
if user:
    print(f"   ✓ Authentication successful: {user.username}")
    print(f"   - is_superuser: {user.is_superuser}")
else:
    print("   ✗ Authentication FAILED!")
    sys.exit(1)

# 4. Test TokenCreateApi directly
print("\n4. Testing TokenCreateApi view...")
try:
    # Create request with proper data
    request = factory.post('/api/v1/authentication/tokens/',
                          data={'username': 'admin', 'password': 'admin'},
                          content_type='application/json')

    # Add session
    from django.contrib.sessions.backends.db import SessionStore
    request.session = SessionStore()
    request.session.create()

    # Add user (anonymous initially)
    from django.contrib.auth.models import AnonymousUser
    request.user = AnonymousUser()

    # Test the view
    view = TokenCreateApi.as_view()
    response = view(request)

    print(f"   - Status code: {response.status_code}")
    print(f"   - Response data: {response.data}")

    if response.status_code == 200:
        if response.data.get('error') == 'mfa_unset':
            print("   ✓ Login successful - MFA setup required (expected)")
        else:
            print("   ✓ Login successful")
    elif response.status_code == 400:
        print(f"   ⚠ Login failed: {response.data.get('error')}")
    else:
        print(f"   ✗ Unexpected status code: {response.status_code}")

except Exception as e:
    print(f"   ✗ Error testing view: {e}")
    import traceback
    traceback.print_exc()

print("\n" + "=" * 60)
print("DIAGNOSIS COMPLETE")
print("=" * 60)
