#!/bin/bash
# Reset admin user's MFA configuration for testing

cd ~/js/apps || cd /home/jsroot/js/apps || cd apps

if [ ! -f "manage.py" ]; then
    echo "Error: manage.py not found"
    exit 1
fi

source ../venv/bin/activate || source venv/bin/activate

echo "=== Resetting Admin MFA Configuration ==="
echo ""

python manage.py shell <<'PYEOF'
from users.models import User

try:
    user = User.objects.get(username='admin')

    print(f"Current MFA status for {user.username}:")
    print(f"  - mfa_level: {user.mfa_level}")
    print(f"  - otp_secret_key: {'***SET***' if user.otp_secret_key else 'NOT SET'}")
    print("")

    # Reset MFA configuration
    user.otp_secret_key = None
    user.mfa_level = 0
    user.save(update_fields=['otp_secret_key', 'mfa_level'])

    print("✓ MFA configuration reset successfully")
    print(f"  - mfa_level: {user.mfa_level}")
    print(f"  - otp_secret_key: {'SET' if user.otp_secret_key else 'NOT SET'}")
    print("")
    print("Admin can now go through MFA setup again.")

except User.DoesNotExist:
    print("✗ User 'admin' not found")
except Exception as e:
    print(f"✗ Error: {e}")
    import traceback
    traceback.print_exc()

PYEOF

echo ""
echo "=== Done ==="
echo "You can now login at: https://192.168.148.154/"
echo "The MFA setup flow will start fresh."
