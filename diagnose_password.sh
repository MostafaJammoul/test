#!/bin/bash
# Diagnose why password authentication is failing

cd ~/js/apps || cd /home/jsroot/js/apps || cd apps

if [ ! -f "manage.py" ]; then
    echo "Error: manage.py not found"
    exit 1
fi

source ../venv/bin/activate || source venv/bin/activate

echo "=== Password Authentication Diagnostic ==="
echo ""

python manage.py shell <<'PYEOF'
from users.models import User
from django.contrib.auth.hashers import make_password, check_password

print("=== Checking admin user in database ===")
try:
    user = User.objects.get(username='admin')
    print(f"✓ User exists: {user.username}")
    print(f"  ID: {user.id}")
    print(f"  is_active: {user.is_active}")
    print(f"  is_superuser: {user.is_superuser}")
    print(f"  is_staff: {user.is_staff}")
    print(f"  role: {user.role}")
    print(f"  Password hash: {user.password[:60]}...")

    print("\n=== Testing password verification ===")

    # Test 1: Direct password check
    if user.check_password('admin'):
        print("✓ Password check PASSED for 'admin'")
    else:
        print("✗ Password check FAILED for 'admin'")

    # Test 2: Check password hash directly
    if check_password('admin', user.password):
        print("✓ Hash verification PASSED for 'admin'")
    else:
        print("✗ Hash verification FAILED for 'admin'")

    # Test 3: Try setting password again with verbose output
    print("\n=== Setting password again ===")
    old_hash = user.password
    user.password = make_password('admin')
    new_hash = user.password

    print(f"Old hash: {old_hash[:60]}...")
    print(f"New hash: {new_hash[:60]}...")
    print(f"Hashes match: {old_hash == new_hash}")

    # Verify new hash
    if check_password('admin', new_hash):
        print("✓ New hash VERIFIED successfully")

        # Save to database
        user.is_active = True
        user.is_superuser = True
        user.is_staff = True
        user.role = 'Admin'
        user.save()
        print("✓ User saved to database")

        # Re-fetch from database to confirm
        user_refetch = User.objects.get(username='admin')
        if check_password('admin', user_refetch.password):
            print("✓ Password VERIFIED after re-fetching from database")
        else:
            print("✗ Password FAILED after re-fetching from database")
            print(f"  Database hash: {user_refetch.password[:60]}...")
    else:
        print("✗ New hash verification FAILED")

except User.DoesNotExist:
    print("✗ User 'admin' does not exist")
except Exception as e:
    print(f"✗ Error: {e}")
    import traceback
    traceback.print_exc()

print("\n=== Testing authentication backends ===")
from django.contrib.auth import authenticate

# Test authentication
user_auth = authenticate(username='admin', password='admin')
if user_auth:
    print(f"✓ Django authenticate() PASSED: {user_auth.username}")
else:
    print("✗ Django authenticate() FAILED")

    # Try to see why it failed
    print("\nTrying to debug authentication failure...")
    from users.models import User
    try:
        user = User.objects.get(username='admin')
        print(f"  User exists: {user.username}")
        print(f"  User is_active: {user.is_active}")

        if not user.is_active:
            print("  ⚠ User is NOT active!")

        if user.check_password('admin'):
            print("  ✓ Password check passes in database")
            print("  ⚠ But authenticate() failed - check authentication backends")
        else:
            print("  ✗ Password check fails in database")
            print("  ⚠ Password hash may be corrupted")
    except Exception as e:
        print(f"  Error: {e}")

PYEOF

echo ""
echo "=== Testing API Login ==="
RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/authentication/tokens/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}')

echo "Response: $RESPONSE"

if echo "$RESPONSE" | grep -q "token"; then
    echo "✓ API login SUCCESSFUL"
elif echo "$RESPONSE" | grep -q "mfa_required"; then
    echo "✓ API login SUCCESSFUL - MFA required"
elif echo "$RESPONSE" | grep -q "password_failed"; then
    echo "✗ API login FAILED - password_failed"
else
    echo "⚠ Unexpected response"
fi

echo ""
echo "=== Diagnosis Complete ==="
