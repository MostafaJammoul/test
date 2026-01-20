#!/bin/bash
# Quick diagnostic script to check admin user

echo "=========================================="
echo "Admin User Diagnostic"
echo "=========================================="
echo ""

cd /home/user/test/apps 2>/dev/null || cd ~/js/apps || cd apps

echo "1. Checking if admin user exists in database..."
python manage.py shell <<PYTHON
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import check_password

User = get_user_model()

try:
    admin = User.objects.get(username='admin')
    print(f"✓ User found: {admin.username}")
    print(f"  ID: {admin.id}")
    print(f"  Email: {admin.email}")
    print(f"  Is active: {admin.is_active}")
    print(f"  Is staff: {admin.is_staff}")
    print(f"  Is superuser: {admin.is_superuser}")
    print(f"  Has password: {bool(admin.password)}")
    print(f"  Password length: {len(admin.password) if admin.password else 0}")
    print(f"")
    print(f"2. Testing password 'admin':")
    is_valid = check_password('admin', admin.password)
    print(f"  Password 'admin' works: {is_valid}")

    if not is_valid:
        print(f"")
        print(f"✗ PASSWORD INCORRECT! Fixing now...")
        admin.set_password('admin')
        admin.save()
        print(f"  ✓ Password reset to 'admin'")

        # Verify fix
        admin.refresh_from_db()
        is_valid_now = check_password('admin', admin.password)
        print(f"  ✓ Verification: Password now works: {is_valid_now}")

except User.DoesNotExist:
    print(f"✗ Admin user does NOT exist!")
    print(f"")
    print(f"Creating admin user now...")
    admin = User.objects.create_superuser(
        username='admin',
        email='admin@example.com',
        password='admin'
    )
    print(f"✓ Admin user created")
    print(f"  Username: admin")
    print(f"  Password: admin")
except Exception as e:
    print(f"✗ Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON

echo ""
echo "=========================================="
echo "Try logging in again with admin/admin"
echo "=========================================="
