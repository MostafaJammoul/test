#!/bin/bash
# Set a strong password for admin user that passes complexity checks

cd ~/js/apps || cd /home/jsroot/js/apps || cd apps

if [ ! -f "manage.py" ]; then
    echo "Error: manage.py not found. Are you in the correct directory?"
    exit 1
fi

source ../venv/bin/activate || source venv/bin/activate

echo "=== Setting Admin Password ==="
echo ""
echo "Options:"
echo "1. Use a strong password: Admin@2024!Secure"
echo "2. Bypass password complexity check (for testing only)"
echo ""
read -p "Enter choice (1 or 2): " choice

case $choice in
    1)
        NEW_PASSWORD="Admin@2024!Secure"
        echo "Setting password to: $NEW_PASSWORD"
        python manage.py shell <<PYEOF
from users.models import User
user = User.objects.get(username='admin')
user.set_password('$NEW_PASSWORD')
user.is_superuser = True
user.is_staff = True
user.is_active = True
user.role = 'Admin'
user.save()
print("✓ Password set to: $NEW_PASSWORD")
PYEOF
        echo ""
        echo "✓ Admin password updated successfully"
        echo "  Username: admin"
        echo "  Password: $NEW_PASSWORD"
        ;;

    2)
        echo "Disabling password complexity check for admin user..."
        python manage.py shell <<'PYEOF'
from users.models import User
from django.contrib.auth.hashers import make_password

# Get admin user
user = User.objects.get(username='admin')

# Set password directly (bypasses complexity check in set_password)
user.password = make_password('admin')
user.is_superuser = True
user.is_staff = True
user.is_active = True
user.role = 'Admin'
user.save()

print("✓ Password set to: admin (complexity check bypassed)")
print("⚠ WARNING: This is insecure and only for testing!")
PYEOF
        echo ""
        echo "✓ Admin password set to 'admin' (insecure - testing only)"
        echo "  Username: admin"
        echo "  Password: admin"
        ;;

    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "=== Testing Login ==="
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/authentication/tokens/ \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"admin\",\"password\":\"$NEW_PASSWORD\"}" 2>&1)

if echo "$TOKEN_RESPONSE" | grep -q "token"; then
    echo "✓ Login test PASSED"
elif echo "$TOKEN_RESPONSE" | grep -q "mfa_required"; then
    echo "✓ Login successful - MFA setup required (expected)"
elif echo "$TOKEN_RESPONSE" | grep -q "passwd_too_simple"; then
    echo "✗ Password still too simple - try option 1 with stronger password"
else
    echo "⚠ Login test returned: $TOKEN_RESPONSE"
fi

echo ""
echo "=== Done ==="
echo "You can now login at: http://192.168.148.154:3000"
