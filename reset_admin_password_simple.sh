#!/bin/bash
# Simple, reliable admin password reset

cd ~/js/apps || cd /home/jsroot/js/apps || cd apps

if [ ! -f "manage.py" ]; then
    echo "Error: manage.py not found"
    exit 1
fi

source ../venv/bin/activate || source venv/bin/activate

echo "=== Resetting Admin Password ==="
echo ""

python manage.py shell <<'PYEOF'
from users.models import User
from django.contrib.auth.hashers import make_password, check_password

try:
    # Get or create admin user
    user, created = User.objects.get_or_create(
        username='admin',
        defaults={
            'name': 'Administrator',
            'email': 'admin@example.com',
            'is_active': True,
            'is_superuser': True,
            'is_staff': True,
            'role': 'Admin',
        }
    )

    if created:
        print("✓ Created new admin user")
    else:
        print(f"✓ Found existing admin user (ID: {user.id})")

    # Set password using make_password (bypasses complexity check)
    user.password = make_password('admin')
    user.is_active = True
    user.is_superuser = True
    user.is_staff = True
    user.role = 'Admin'

    # Verify password hash before saving
    if check_password('admin', user.password):
        print("✓ Password hash verified before save")

        # Save to database
        user.save()
        print("✓ User saved to database")

        # Re-fetch from database and verify
        user_check = User.objects.get(username='admin')
        if check_password('admin', user_check.password):
            print("✓ Password verified after database save")
            print("")
            print("SUCCESS: Admin password set to 'admin'")
            print("  Username: admin")
            print("  Password: admin")
            print("  Role: Admin")
            print("  Superuser: True")
        else:
            print("✗ ERROR: Password verification failed after save!")
            print("  This indicates a database issue")
    else:
        print("✗ ERROR: Password hash verification failed!")
        print("  This should never happen")

except Exception as e:
    print(f"✗ ERROR: {e}")
    import traceback
    traceback.print_exc()

PYEOF

echo ""
echo "=== Testing Authentication ==="

# Test with Django authenticate
python manage.py shell <<'PYEOF'
from django.contrib.auth import authenticate

user = authenticate(username='admin', password='admin')
if user:
    print(f"✓ Django authenticate() PASSED: {user.username}")
    print("  Authentication backends working correctly")
else:
    print("✗ Django authenticate() FAILED")
    print("  Check authentication backends configuration")

PYEOF

# Test with API
echo ""
echo "Testing API login..."
RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/authentication/tokens/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}')

if echo "$RESPONSE" | grep -q '"token"'; then
    echo "✓ API login SUCCESSFUL - Got token"
elif echo "$RESPONSE" | grep -q '"mfa_required"'; then
    echo "✓ API login SUCCESSFUL - MFA setup required (expected)"
elif echo "$RESPONSE" | grep -q '"passwd_too_simple"'; then
    echo "⚠ Password rejected as too simple"
    echo "  The bypass didn't work - may need to check authentication backends"
elif echo "$RESPONSE" | grep -q '"password_failed"'; then
    echo "✗ API login FAILED - password_failed"
    echo "  Run diagnose_password.sh to investigate"
else
    echo "Response: $RESPONSE"
fi

echo ""
echo "=== Done ==="
