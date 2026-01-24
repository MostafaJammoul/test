#!/bin/bash
set -e

echo "=========================================="
echo "JumpServer Diagnostic & Fix Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find the correct data directory
if [ -d "/truefypjs/data" ]; then
    DATA_DIR="/truefypjs"
    echo "✓ Found data directory: /truefypjs"
elif [ -d "$HOME/truefypjs/data" ]; then
    DATA_DIR="$HOME/truefypjs"
    echo "✓ Found data directory: $HOME/truefypjs"
elif [ -d "/home/user/test/data" ]; then
    DATA_DIR="/home/user/test"
    echo "✓ Found data directory: /home/user/test"
else
    DATA_DIR="/home/user/test"
    echo "⚠  Using default: /home/user/test"
fi

echo "Data directory: $DATA_DIR"
echo ""

# ====================
# 1. CHECK CERTIFICATES
# ====================
echo "1. CHECKING CERTIFICATES..."
echo ""

if [ -f "$DATA_DIR/data/certs/mtls/internal-ca.crt" ]; then
    echo -e "${GREEN}✓${NC} CA Certificate exists"
    openssl x509 -in "$DATA_DIR/data/certs/mtls/internal-ca.crt" -noout -subject -dates 2>&1 | head -3
else
    echo -e "${RED}✗${NC} CA Certificate NOT FOUND at $DATA_DIR/data/certs/mtls/internal-ca.crt"
fi

if [ -f "$DATA_DIR/data/certs/mtls/server.crt" ]; then
    echo -e "${GREEN}✓${NC} Server Certificate exists"
else
    echo -e "${RED}✗${NC} Server Certificate NOT FOUND"
fi

echo ""

# ====================
# 2. FIX ADMIN USER PASSWORD
# ====================
echo "2. FIXING ADMIN USER PASSWORD..."
echo ""

# Create Python script to fix password
cat > /tmp/fix_admin_password.py <<'PYTHON_SCRIPT'
#!/usr/bin/env python3
import os
import sys
import django

# Setup Django
sys.path.insert(0, '/home/user/test/apps')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'jumpserver.settings')
django.setup()

from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import make_password, check_password

User = get_user_model()

try:
    admin = User.objects.get(username='admin')
    print(f"Found admin user: {admin.username}")
    print(f"  Email: {admin.email}")
    print(f"  Is Active: {admin.is_active}")
    print(f"  Is Superuser: {admin.is_superuser}")

    # Check current password
    if admin.password and check_password('admin', admin.password):
        print("  ✓ Password 'admin' is already correct")
    else:
        print("  ✗ Password is NOT set to 'admin', fixing...")
        admin.password = make_password('admin')
        admin.is_active = True
        admin.is_staff = True
        admin.is_superuser = True
        admin.save(update_fields=['password', 'is_active', 'is_staff', 'is_superuser'])
        print("  ✓ Password reset to 'admin'")
        print("  ✓ User flags updated")

except User.DoesNotExist:
    print("❌ Admin user does not exist!")
    print("Creating admin user...")
    User.objects.create_superuser(
        username='admin',
        email='admin@example.com',
        password='admin'
    )
    print("✓ Admin user created with password 'admin'")
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON_SCRIPT

# Run the fix script
if command -v python3 &> /dev/null; then
    python3 /tmp/fix_admin_password.py
else
    echo -e "${RED}✗${NC} Python3 not found"
fi

echo ""

# ====================
# 3. UPDATE NGINX CONFIGURATION
# ====================
echo "3. UPDATING NGINX CONFIGURATION..."
echo ""

NGINX_CONF="$DATA_DIR/nginx-jumpserver.conf"

if [ -f "$NGINX_CONF" ]; then
    echo "  Updating paths in nginx config..."

    # Create backup
    cp "$NGINX_CONF" "$NGINX_CONF.backup.$(date +%s)"

    # Update paths using sed
    sed -i "s|/home/jsroot/js/|$DATA_DIR/|g" "$NGINX_CONF"

    echo -e "${GREEN}✓${NC} Nginx config updated"
    echo "  Paths changed to: $DATA_DIR/"
else
    echo -e "${RED}✗${NC} Nginx config not found at $NGINX_CONF"
fi

echo ""

# ====================
# 4. CHECK NGINX STATUS
# ====================
echo "4. CHECKING NGINX..."
echo ""

if pgrep nginx > /dev/null; then
    echo -e "${GREEN}✓${NC} Nginx is running"

    # Check if config is loaded
    if [ -f "/etc/nginx/sites-enabled/jumpserver" ]; then
        echo -e "${GREEN}✓${NC} Jumpserver nginx config is enabled"
    else
        echo -e "${YELLOW}⚠${NC}  Jumpserver nginx config NOT enabled"
        echo "  To enable:"
        echo "    sudo cp $NGINX_CONF /etc/nginx/sites-available/jumpserver"
        echo "    sudo ln -sf /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/"
        echo "    sudo nginx -t"
        echo "    sudo systemctl reload nginx"
    fi
else
    echo -e "${YELLOW}⚠${NC}  Nginx is NOT running"
fi

echo ""

# ====================
# 5. SUMMARY & NEXT STEPS
# ====================
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo ""
echo "✓ Admin password should now be: admin/admin"
echo "✓ Nginx config paths updated"
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Start Django backend:"
echo "   cd $DATA_DIR/apps"
echo "   python3 manage.py runserver 0.0.0.0:8080"
echo ""
echo "2. Start frontend (separate terminal):"
echo "   cd $DATA_DIR/frontend"
echo "   npm run dev"
echo ""
echo "3. Access the application:"
echo "   http://<your-vm-ip>:3000"
echo ""
echo "4. Login with:"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "5. To enable HTTPS/mTLS (optional):"
echo "   sudo cp $NGINX_CONF /etc/nginx/sites-available/jumpserver"
echo "   sudo ln -sf /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/"
echo "   sudo nginx -t && sudo systemctl reload nginx"
echo ""
echo "=========================================="
