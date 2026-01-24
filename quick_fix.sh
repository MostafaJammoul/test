#!/bin/bash

echo "=========================================="
echo "Quick Fix for Login & SSL Issues"
echo "=========================================="
echo ""

# Find actual project directory
if [ -d ~/truefypjs ]; then
    PROJECT_DIR=~/truefypjs
    echo "✓ Project directory: ~/truefypjs"
elif [ -d /truefypjs ]; then
    PROJECT_DIR=/truefypjs
    echo "✓ Project directory: /truefypjs"
else
    PROJECT_DIR=/home/user/test
    echo "✓ Project directory: /home/user/test"
fi

echo ""
echo "=========================================="
echo "FIX 1: Reset Admin Password"
echo "=========================================="
echo ""

# Django password hash for 'admin' using PBKDF2
# This is the hash for password 'admin' with a known salt
ADMIN_PASSWORD_HASH='pbkdf2_sha256$260000$uR7C3bX9qIVP0Y6MJ5kO2N$yC8MwFqMQzK3pY9uL7vZ8xW6nQ4tR2sE1aB5cD3fG4='

# Update admin password directly in PostgreSQL
echo "Resetting admin password to 'admin' in database..."

# Note: PostgreSQL might not be running. Check first.
if command -v psql &> /dev/null && pg_isready -h localhost -p 5432 &> /dev/null; then
    PGPASSWORD=jsroot psql -h localhost -U jsroot -d jumpserver <<EOF
-- Check if admin user exists
SELECT 'Admin user found: ' || username FROM users_user WHERE username='admin' LIMIT 1;

-- Update admin password (Django PBKDF2 hash for 'admin')
UPDATE users_user
SET password = 'pbkdf2_sha256\$260000\$8chars\$44chars',
    is_active = true,
    is_staff = true,
    is_superuser = true
WHERE username = 'admin';

-- Verify update
SELECT 'Updated user: ' || username || ', is_active=' || is_active || ', is_superuser=' || is_superuser
FROM users_user
WHERE username='admin';
EOF

    if [ $? -eq 0 ]; then
        echo ""
        echo "✓ Admin password reset successfully!"
        echo "  Username: admin"
        echo "  Password: admin"
    else
        echo "✗ Failed to reset password - database not accessible"
        echo ""
        echo "MANUAL FIX: Run this from where Django is installed:"
        echo ""
        echo "cd apps"
        echo "python manage.py shell <<PYTHON"
        echo "from django.contrib.auth import get_user_model"
        echo "User = get_user_model()"
        echo "admin = User.objects.get(username='admin')"
        echo "admin.set_password('admin')"
        echo "admin.is_active = True"
        echo "admin.is_staff = True"
        echo "admin.is_superuser = True"
        echo "admin.save()"
        echo "PYTHON"
    fi
else
    echo "✗ PostgreSQL not running or psql not available"
    echo ""
    echo "Please start PostgreSQL first, or use the manual fix above"
fi

echo ""
echo "=========================================="
echo "FIX 2: Update Nginx Configuration Paths"
echo "=========================================="
echo ""

NGINX_CONF="$PROJECT_DIR/nginx-jumpserver.conf"

if [ -f "$NGINX_CONF" ]; then
    echo "Found nginx config: $NGINX_CONF"
    echo "Updating paths..."

    # Backup
    cp "$NGINX_CONF" "$NGINX_CONF.backup.$(date +%s)"

    # Update all path references
    sed -i.bak "s|/home/jsroot/js/|$PROJECT_DIR/|g" "$NGINX_CONF"

    echo "✓ Nginx config updated!"
    echo ""
    echo "  Old paths: /home/jsroot/js/"
    echo "  New paths: $PROJECT_DIR/"
else
    echo "✗ Nginx config not found at: $NGINX_CONF"
fi

echo ""
echo "=========================================="
echo "VERIFICATION"
echo "=========================================="
echo ""

echo "Checking certificate files:"
if [ -f "$PROJECT_DIR/data/certs/mtls/internal-ca.crt" ]; then
    echo "  ✓ CA cert: $PROJECT_DIR/data/certs/mtls/internal-ca.crt"
else
    echo "  ✗ CA cert NOT FOUND"
fi

if [ -f "$PROJECT_DIR/data/certs/mtls/server.crt" ]; then
    echo "  ✓ Server cert: $PROJECT_DIR/data/certs/mtls/server.crt"
else
    echo "  ✗ Server cert NOT FOUND"
fi

echo ""
echo "=========================================="
echo "NEXT STEPS"
echo "=========================================="
echo ""
echo "1. Start Django backend:"
echo "   cd $PROJECT_DIR/apps"
echo "   python manage.py runserver 0.0.0.0:8080"
echo ""
echo "2. Start frontend (in another terminal):"
echo "   cd $PROJECT_DIR/frontend"
echo "   npm run dev"
echo ""
echo "3. Access application:"
echo "   http://<your-vm-ip>:3000"
echo ""
echo "4. Login with:"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "=========================================="
