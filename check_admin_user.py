#!/usr/bin/env python3
"""
Quick script to check admin user in database
"""
import sys
import os

# Add apps directory to path
sys.path.insert(0, '/home/user/test/apps')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'jumpserver.settings')

try:
    import django
    django.setup()

    from django.contrib.auth import get_user_model
    from django.contrib.auth.hashers import check_password

    User = get_user_model()

    print("=" * 60)
    print("ADMIN USER CHECK")
    print("=" * 60)

    # Get admin user
    admin = User.objects.filter(username='admin').first()

    if not admin:
        print("❌ Admin user NOT FOUND in database!")
        print("\nAll users:")
        for u in User.objects.all()[:5]:
            print(f"  - {u.username} (ID: {u.id})")
    else:
        print(f"✅ Admin user FOUND")
        print(f"\nUsername: {admin.username}")
        print(f"Email: {admin.email}")
        print(f"ID: {admin.id}")
        print(f"Is Active: {admin.is_active}")
        print(f"Is Superuser: {admin.is_superuser}")
        print(f"Is Staff: {admin.is_staff}")
        print(f"Has Password: {bool(admin.password)}")
        print(f"Password Hash: {admin.password[:50] if admin.password else 'NONE'}...")

        # Test password
        if admin.password:
            print(f"\nTesting password 'admin':")
            is_valid = check_password('admin', admin.password)
            print(f"  Password 'admin' is {'✅ VALID' if is_valid else '❌ INVALID'}")

            if not is_valid:
                print("\n⚠️  Password hash doesn't match 'admin'!")
                print("  Possible issues:")
                print("  1. Password was set to something else")
                print("  2. Password wasn't properly hashed during creation")
                print("  3. setup.sh didn't complete successfully")

                # Try to fix
                print("\n🔧 Fixing password...")
                admin.set_password('admin')
                admin.save()
                print("  ✅ Password reset to 'admin'")

                # Verify fix
                admin.refresh_from_db()
                is_valid_now = check_password('admin', admin.password)
                print(f"  Verification: {'✅ SUCCESS' if is_valid_now else '❌ STILL FAILED'}")
        else:
            print("\n❌ User has NO password set!")
            print("🔧 Setting password to 'admin'...")
            admin.set_password('admin')
            admin.save()
            print("  ✅ Password set successfully")

    print("\n" + "=" * 60)

except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
