# Troubleshooting Guide

## Issue 1: Login Fails with "User login failed: admin"

### Root Cause
The admin user's password is not properly set or hashed in the database.

### Fix

**Step 1: Find where Django is running**

You said the server is running and showing logs. Find that terminal/process and go to that directory.

**Step 2: Reset admin password**

From the directory where you're running Django (the one with `apps/` folder):

```bash
cd apps
python manage.py shell
```

Then in the Python shell:

```python
from django.contrib.auth import get_user_model
User = get_user_model()

# Get or create admin user
admin, created = User.objects.get_or_create(
    username='admin',
    defaults={
        'email': 'admin@example.com',
        'is_staff': True,
        'is_superuser': True,
        'is_active': True
    }
)

# Set password
admin.set_password('admin')
admin.is_active = True
admin.is_staff = True
admin.is_superuser = True
admin.save()

print(f"✓ Admin user {'created' if created else 'updated'}")
print(f"  Username: {admin.username}")
print(f"  Email: {admin.email}")
print(f"  Is Active: {admin.is_active}")
print(f"  Is Superuser: {admin.is_superuser}")

# Test password
from django.contrib.auth.hashers import check_password
is_valid = check_password('admin', admin.password)
print(f"  Password 'admin' works: {is_valid}")

exit()
```

**Step 3: Restart Django server**

Stop the current server (Ctrl+C) and restart:

```bash
python manage.py runserver 0.0.0.0:8080
```

**Step 4: Try logging in again**
- Go to: http://192.168.148.154:3000
- Username: `admin`
- Password: `admin`

---

## Issue 2: HTTPS Access Returns HTTP 400 SSL Error

### Root Cause
The `nginx-jumpserver.conf` file has wrong certificate paths.

### Current Config (WRONG)
```nginx
ssl_certificate /home/jsroot/js/data/certs/mtls/server.crt;
ssl_certificate_key /home/jsroot/js/data/certs/mtls/server.key;
ssl_client_certificate /home/jsroot/js/data/certs/mtls/internal-ca.crt;
```

### Your Actual Paths (from screenshot)
```
~/truefypjs/data/certs/mtls/internal-ca.crt
~/truefypjs/data/certs/mtls/server.crt
~/truefypjs/data/certs/mtls/server.key
```

### Fix

**Step 1: Find your actual project directory**

```bash
pwd
ls -la ~/truefypjs/data/certs/mtls/
```

If that shows your certificates, then your project is at `~/truefypjs` (likely `/home/jsroot/truefypjs`).

**Step 2: Update nginx configuration**

```bash
cd ~/truefypjs  # or wherever your project is
nano nginx-jumpserver.conf
```

Find these lines (around line 28-33) and update paths:

**BEFORE:**
```nginx
ssl_certificate /home/jsroot/js/data/certs/mtls/server.crt;
ssl_certificate_key /home/jsroot/js/data/certs/mtls/server.key;
ssl_client_certificate /home/jsroot/js/data/certs/mtls/internal-ca.crt;
```

**AFTER** (use your actual path):
```nginx
ssl_certificate /home/jsroot/truefypjs/data/certs/mtls/server.crt;
ssl_certificate_key /home/jsroot/truefypjs/data/certs/mtls/server.key;
ssl_client_certificate /home/jsroot/truefypjs/data/certs/mtls/internal-ca.crt;
```

Or if it's just `~/truefypjs`:
```nginx
ssl_certificate ~/truefypjs/data/certs/mtls/server.crt;
ssl_certificate_key ~/truefypjs/data/certs/mtls/server.key;
ssl_client_certificate ~/truefypjs/data/certs/mtls/internal-ca.crt;
```

**Also update these paths** (around line 56, 61, 68):
```nginx
root /home/jsroot/truefypjs/apps/static/frontend;  # Line 56
alias /home/jsroot/truefypjs/apps/static/;         # Line 61
alias /home/jsroot/truefypjs/data/media/;          # Line 68
```

**Step 3: Install nginx config**

```bash
sudo cp nginx-jumpserver.conf /etc/nginx/sites-available/jumpserver
sudo ln -sf /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/jumpserver

# Test config
sudo nginx -t

# If test passes, reload nginx
sudo systemctl reload nginx
# Or if no systemd:
sudo nginx -s reload
```

**Step 4: Test HTTPS**

```bash
# From VM
curl -k https://localhost/api/health/

# From your host OS browser
# Visit: https://192.168.148.154/
# (Accept self-signed certificate warning)
```

---

## Quick Diagnosis Commands

Run these to understand your setup:

```bash
# 1. Find your project directory
pwd
echo "Home: $HOME"
ls -la ~/truefypjs 2>/dev/null || echo "Not at ~/truefypjs"
ls -la /home/user/test 2>/dev/null || echo "Not at /home/user/test"

# 2. Find certificates
find ~ -name "internal-ca.crt" 2>/dev/null

# 3. Check if Django server is running
ps aux | grep "manage.py runserver"

# 4. Check if nginx is running
ps aux | grep nginx | grep -v grep

# 5. Check database connection
PGPASSWORD=jsroot psql -h localhost -U jsroot -d jumpserver -c "SELECT username, is_active, is_superuser FROM users_user WHERE username='admin';"
```

---

## If Database is Not Running

Start PostgreSQL:

```bash
# Check status
sudo systemctl status postgresql
# Or
pg_isready

# Start if needed
sudo systemctl start postgresql
# Or
sudo service postgresql start
```

---

## Summary of Fixes

| Issue | Fix | Command |
|-------|-----|---------|
| **Login fails** | Reset admin password | `python manage.py shell` → set_password('admin') |
| **HTTPS 400 error** | Update nginx cert paths | Edit `nginx-jumpserver.conf` |
| **Can't find project** | Use `pwd` and `find` | See diagnosis commands above |

---

## Expected URLs After Fixes

| URL | Purpose | Auth Required |
|-----|---------|---------------|
| http://192.168.148.154:3000 | Frontend (dev server) | Yes - admin/admin |
| http://192.168.148.154:8080 | Backend API (direct) | No (for health check) |
| https://192.168.148.154/ | Frontend via nginx | Yes - admin/admin or mTLS cert |
| http://192.168.148.154:8080/django-admin/ | Django admin panel | Yes - admin/admin |

---

## Still Having Issues?

Run this diagnostic script and share the output:

```bash
#!/bin/bash
echo "=== PROJECT LOCATION ==="
pwd
echo ""
echo "=== CERTIFICATE LOCATIONS ==="
find ~ -name "internal-ca.crt" 2>/dev/null
echo ""
echo "=== RUNNING PROCESSES ==="
ps aux | grep -E "(python|node|nginx|postgres)" | grep -v grep
echo ""
echo "=== ADMIN USER IN DATABASE ==="
PGPASSWORD=jsroot psql -h localhost -U jsroot -d jumpserver -c "SELECT username, email, is_active, is_superuser, length(password) as pass_len FROM users_user WHERE username='admin';" 2>&1
echo ""
echo "=== NGINX CONFIG PATHS ==="
grep -E "ssl_certificate|root|alias" nginx-jumpserver.conf 2>/dev/null | head -10
```

Save this as `diagnose.sh`, make it executable (`chmod +x diagnose.sh`), run it (`./diagnose.sh`), and share the output.
