#!/bin/bash
# Emergency admin password fix

echo "Fixing admin password..."

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

echo "Working in: $(pwd)"
echo ""

# Fix admin password
python manage.py shell <<'PYTHON'
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import check_password

User = get_user_model()

try:
    admin = User.objects.get(username='admin')
    print(f"Found user: {admin.username}")
    print(f"  Is active: {admin.is_active}")
    print(f"  Is superuser: {admin.is_superuser}")

    # Check current password
    if check_password('admin', admin.password):
        print(f"  ✓ Password already correct!")
    else:
        print(f"  ✗ Password is WRONG - fixing...")
        admin.set_password('admin')
        admin.is_active = True
        admin.is_staff = True
        admin.is_superuser = True
        admin.save()
        print(f"  ✓ Password reset to 'admin'")

        # Verify
        admin.refresh_from_db()
        if check_password('admin', admin.password):
            print(f"  ✓ Verification: SUCCESS!")
        else:
            print(f"  ✗ Verification: FAILED!")

except User.DoesNotExist:
    print("✗ Admin user doesn't exist - creating...")
    admin = User.objects.create_superuser(
        username='admin',
        email='admin@example.com',
        password='admin'
    )
    print(f"✓ Created admin user")

except Exception as e:
    print(f"✗ Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON

echo ""
echo "Done! Try logging in again with admin/admin"
