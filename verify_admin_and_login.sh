#!/bin/bash

cd "$(dirname "$0")/backend"

echo "========================================="
echo "Admin User Verification"
echo "========================================="

python manage.py shell <<'PYTHON'
from django.contrib.auth import get_user_model
from rbac.builtin import BuiltinRole

User = get_user_model()

try:
    admin = User.objects.get(username='admin')
    print(f"✓ Admin user found")
    print(f"  - Username: {admin.username}")
    print(f"  - Email: {admin.email}")
    print(f"  - is_active: {admin.is_active}")
    print(f"  - is_staff: {admin.is_staff}")
    print(f"  - is_superuser: {admin.is_superuser}")
    print(f"  - mfa_enabled: {admin.mfa_enabled}")

    # Check password
    password_ok = admin.check_password('admin')
    print(f"  - Password 'admin' works: {password_ok}")

    # Check system roles
    admin_role_id = BuiltinRole.system_admin.id
    has_admin_role = admin.system_roles.filter(id=admin_role_id).exists()
    print(f"  - Has system_admin role: {has_admin_role}")

    # Check if password login would be allowed
    can_use_password = admin.is_superuser or has_admin_role
    print(f"  - Can use password login: {can_use_password}")

    # Test authentication
    print("\n========================================")
    print("Testing Login Flow")
    print("========================================")

    from django.contrib.auth import authenticate
    from django.test import RequestFactory

    factory = RequestFactory()
    request = factory.post('/api/v1/authentication/tokens/')
    request.session = {}

    user = authenticate(request, username='admin', password='admin')
    if user:
        print(f"✓ Authentication successful for user: {user.username}")
        print(f"  - User ID: {user.id}")
        print(f"  - Backend: {getattr(user, 'backend', 'None')}")
    else:
        print("✗ Authentication failed - credentials invalid")

except User.DoesNotExist:
    print("✗ Admin user not found!")
except Exception as e:
    print(f"✗ Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON

echo ""
echo "========================================="
echo "Testing Login API Endpoint"
echo "========================================="

# Test the actual login endpoint
response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST http://localhost:8080/api/v1/authentication/tokens/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}')

http_code=$(echo "$response" | grep "HTTP_STATUS" | cut -d: -f2)
body=$(echo "$response" | sed '/HTTP_STATUS/d')

echo "HTTP Status: $http_code"
echo "Response Body:"
echo "$body" | python -m json.tool 2>/dev/null || echo "$body"

echo ""
echo "========================================="
echo "Analysis"
echo "========================================="

if [ "$http_code" = "200" ]; then
    if echo "$body" | grep -q "mfa_unset"; then
        echo "✓ Login successful - MFA setup required"
        echo "  → Frontend should redirect to /setup-mfa"
        echo "  → Check if frontend was restarted after code changes"
    elif echo "$body" | grep -q "mfa_required"; then
        echo "✓ Login successful - MFA challenge required"
        echo "  → Frontend should redirect to /mfa-challenge"
    else
        echo "✓ Login fully successful"
    fi
elif [ "$http_code" = "400" ]; then
    error=$(echo "$body" | python -c "import sys, json; print(json.load(sys.stdin).get('error', 'unknown'))" 2>/dev/null)
    msg=$(echo "$body" | python -c "import sys, json; print(json.load(sys.stdin).get('msg', 'unknown'))" 2>/dev/null)
    echo "✗ Login failed with error: $error"
    echo "  Message: $msg"
elif [ "$http_code" = "401" ]; then
    echo "✗ Unauthorized - credentials rejected"
else
    echo "✗ Unexpected HTTP status: $http_code"
fi
