#!/bin/bash
# Debug script to see what's happening during admin creation

echo "=========================================="
echo "Admin Creation Debug"
echo "=========================================="
echo ""

# Find the correct directory
if [ -d ~/js/apps ]; then
    cd ~/js/apps
elif [ -d /home/jsroot/js/apps ]; then
    cd /home/jsroot/js/apps
elif [ -d /home/user/test/apps ]; then
    cd /home/user/test/apps
else
    echo "Cannot find apps directory!"
    exit 1
fi

echo "Working directory: $(pwd)"
echo ""

# Set variables exactly like setup.sh
SUPERUSER_NAME=${SUPERUSER_USERNAME:-"admin"}
SUPERUSER_EMAIL=${SUPERUSER_EMAIL:-"admin@example.com"}
SUPERUSER_PASSWORD=${SUPERUSER_PASSWORD:-"admin"}

echo "Variables:"
echo "  SUPERUSER_NAME='$SUPERUSER_NAME'"
echo "  SUPERUSER_EMAIL='$SUPERUSER_EMAIL'"
echo "  SUPERUSER_PASSWORD='$SUPERUSER_PASSWORD'"
echo ""

echo "1. Testing variable expansion in heredoc..."
cat <<TEST_HEREDOC
Username will be: $SUPERUSER_NAME
Email will be: $SUPERUSER_EMAIL
Password will be: $SUPERUSER_PASSWORD
TEST_HEREDOC
echo ""

echo "2. Running the exact same Python code from setup.sh..."
echo ""

# Use the EXACT same heredoc as setup.sh
python manage.py shell <<PYTHON_SUPERUSER
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import make_password

User = get_user_model()

print(f"User model: {User}")
print(f"User model path: {User.__module__}.{User.__name__}")
print("")

# Get or create admin user
admin, created = User.objects.get_or_create(
    username='$SUPERUSER_NAME',
    defaults={
        'email': '$SUPERUSER_EMAIL',
        'is_staff': True,
        'is_superuser': True,
        'is_active': True
    }
)

print(f"Admin user {'created' if created else 'updated'}: {admin.username}")
print(f"  Email: {admin.email}")
print(f"  Is superuser: {admin.is_superuser}")
print(f"  Is active: {admin.is_active}")
print(f"  Has password: {bool(admin.password)}")
print("")

# Always set password to ensure it's correct (using set_password for proper hashing)
print(f"Setting password to: '$SUPERUSER_PASSWORD'")
admin.set_password('$SUPERUSER_PASSWORD')
admin.is_staff = True
admin.is_superuser = True
admin.is_active = True
admin.email = '$SUPERUSER_EMAIL'
admin.save()

print(f"Saved!")
print("")

# Test password immediately
from django.contrib.auth.hashers import check_password
password_works = check_password('$SUPERUSER_PASSWORD', admin.password)
print(f"Password test: check_password('$SUPERUSER_PASSWORD', admin.password) = {password_works}")
print(f"Password hash: {admin.password[:80]}...")
PYTHON_SUPERUSER

echo ""
echo "3. Running verification check (like setup.sh does)..."
if python manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); u = User.objects.filter(username='$SUPERUSER_NAME').first(); print(u and u.check_password('$SUPERUSER_PASSWORD'))" 2>/dev/null | grep -q "True"; then
    echo "✓ Verification PASSED: Password works!"
else
    echo "✗ Verification FAILED: Password doesn't work!"
fi

echo ""
echo "4. Checking what's actually in the database..."
python manage.py shell <<CHECK_DB
from django.contrib.auth import get_user_model
User = get_user_model()

try:
    admin = User.objects.get(username='admin')
    print(f"Found user in DB:")
    print(f"  Username: {admin.username}")
    print(f"  Email: {admin.email}")
    print(f"  Is active: {admin.is_active}")
    print(f"  Is staff: {admin.is_staff}")
    print(f"  Is superuser: {admin.is_superuser}")
    print(f"  Password hash (first 80 chars): {admin.password[:80]}")

    # Test password
    from django.contrib.auth.hashers import check_password
    for test_pass in ['admin', 'Admin', 'ADMIN', '']:
        result = check_password(test_pass, admin.password)
        print(f"  Password '{test_pass}': {result}")

except User.DoesNotExist:
    print("✗ No user with username='admin' in database!")
except Exception as e:
    print(f"✗ Error: {e}")
    import traceback
    traceback.print_exc()
CHECK_DB

echo ""
echo "=========================================="
echo "Debug complete!"
echo "=========================================="
