# Quick Fix for Connection Issues

## Problem Summary

1. **Frontend (Port 3000)**: Connection refused due to PostCSS error
2. **Backend (Port 8080)**: 404 errors for `/admin` and `/api/v1/blockchain/`
3. **Root Cause**: Missing migrations prevented Django from setting up URL routing properly

---

## Fix Steps (Execute in Order)

### Step 1: Fix Frontend PostCSS Config

**On Windows:**
```powershell
cd C:\Users\mosta\Desktop\FYP\JumpServer

# Transfer fixed postcss.config.js
scp truefypjs/frontend/postcss.config.js jsroot@192.168.148.154:/home/jsroot/js/frontend/
```

**On VM:**
```bash
# Stop the frontend (Ctrl+C if running)
# Restart it
cd /home/jsroot/js/frontend
npm run dev -- --host 0.0.0.0
```

---

### Step 2: Copy All Missing Migrations to VM

**On Windows:**
```powershell
cd C:\Users\mosta\Desktop\FYP\JumpServer

# Copy all app migrations
scp -r truefypjs/apps/users/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/users/migrations/
scp -r truefypjs/apps/authentication/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/authentication/migrations/
scp -r truefypjs/apps/assets/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/assets/migrations/
scp -r truefypjs/apps/audits/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/audits/migrations/
scp -r truefypjs/apps/ops/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/ops/migrations/
scp -r truefypjs/apps/perms/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/perms/migrations/
scp -r truefypjs/apps/rbac/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/rbac/migrations/
scp -r truefypjs/apps/orgs/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/orgs/migrations/
scp -r truefypjs/apps/settings/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/settings/migrations/
scp -r truefypjs/apps/terminal/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/terminal/migrations/
scp -r truefypjs/apps/tickets/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/tickets/migrations/
scp -r truefypjs/apps/acls/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/acls/migrations/
scp -r truefypjs/apps/accounts/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/accounts/migrations/
scp -r truefypjs/apps/labels/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/labels/migrations/
scp -r truefypjs/apps/notifications/migrations/* jsroot@192.168.148.154:/opt/truefypjs/apps/notifications/migrations/
```

**Faster option (copy all at once):**
```powershell
cd C:\Users\mosta\Desktop\FYP\JumpServer
scp -r truefypjs/apps/*/migrations jsroot@192.168.148.154:/tmp/
```

Then on VM:
```bash
# Copy migrations to correct locations
cd /tmp
for app in users authentication assets audits ops perms rbac orgs settings terminal tickets acls accounts labels notifications; do
  cp -r migrations/* /opt/truefypjs/apps/$app/migrations/ 2>/dev/null || true
done
```

---

### Step 3: Reset and Rebuild Database on VM

**On VM:**
```bash
# Stop Django server (Ctrl+C if running)

# Drop and recreate database
sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS jumpserver;
CREATE DATABASE jumpserver OWNER jsroot;
GRANT ALL PRIVILEGES ON DATABASE jumpserver TO jsroot;
\q
EOF

# Navigate to project
cd /opt/truefypjs/apps
source ../venv/bin/activate

# Run ALL migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser --username bakri

# Start Django server
python manage.py runserver 0.0.0.0:8080
```

---

### Step 4: Verify Everything Works

#### Test 1: Check Django Server

**On VM:**
```bash
# Check if Django is running
ps aux | grep "manage.py runserver"

# Test health endpoint
curl http://localhost:8080/api/health/
```

**From Windows browser:**
```
http://192.168.148.154:8080/admin
```

You should see the Django admin login page.

#### Test 2: Check Frontend

**On VM:**
```bash
# Check if Vite is running
ps aux | grep "vite"

# Check if port 3000 is listening
ss -tlnp | grep 3000
```

**From Windows browser:**
```
http://192.168.148.154:3000
```

You should see the React app (even if unstyled).

---

## Alternative: One-Command Full Reset

If the above doesn't work, run this complete reset script on the VM:

```bash
#!/bin/bash
# Complete reset and migration fix

cd /opt/truefypjs

# 1. Stop services
pkill -f "manage.py runserver"
pkill -f "vite"

# 2. Drop and recreate database
sudo -u postgres psql -c "DROP DATABASE IF EXISTS jumpserver;"
sudo -u postgres psql -c "CREATE DATABASE jumpserver OWNER jsroot;"

# 3. Activate venv
source venv/bin/activate

# 4. Run migrations
cd apps
python manage.py migrate

# 5. Check for errors
python manage.py check

# 6. Create superuser (interactive)
python manage.py createsuperuser --username bakri

# 7. Start Django
python manage.py runserver 0.0.0.0:8080 &

# 8. Start frontend
cd /home/jsroot/js/frontend
npm run dev -- --host 0.0.0.0 &

echo "Done! Check:"
echo "  Backend:  http://192.168.148.154:8080/admin"
echo "  Frontend: http://192.168.148.154:3000"
```

---

## Common Errors and Solutions

### Error: "No module named 'users.model'"

**Cause**: Migrations not copied to VM

**Fix**: Run Step 2 above (copy all migrations)

### Error: "Cannot resolve keyword 'is_superuser'"

**Cause**: Users table doesn't have required columns

**Fix**: Drop database and run migrations again (Step 3)

### Error: "Page not found (404)" for /admin

**Cause**: Django URL routing didn't initialize because migrations failed

**Fix**: Ensure migrations succeed, then restart Django

### Error: Connection refused on port 3000

**Cause**: Vite crashed due to PostCSS error

**Fix**:
1. Transfer fixed postcss.config.js (Step 1)
2. Restart Vite: `npm run dev -- --host 0.0.0.0`

### Error: Connection refused on port 8080

**Cause**: Django crashed or not running

**Fix**: Check Django logs and restart:
```bash
cd /opt/truefypjs/apps
source ../venv/bin/activate
python manage.py runserver 0.0.0.0:8080
```

---

## Verification Checklist

After running all steps:

- [ ] PostgreSQL has `jumpserver` database with `jsroot` owner
- [ ] All migrations completed without errors
- [ ] `python manage.py check` returns no issues
- [ ] Django is running on port 8080
- [ ] `/admin` page shows login form
- [ ] Vite is running on port 3000
- [ ] Frontend loads (even if unstyled)
- [ ] Superuser `bakri` exists and can login

---

## Quick Status Check Commands

```bash
# Check database
PGPASSWORD=jsroot psql -h localhost -U jsroot -d jumpserver -c "\dt users_user"

# Check Django
curl http://localhost:8080/admin | head -20

# Check frontend
curl http://localhost:3000 | head -20

# Check running processes
ps aux | grep -E "manage.py|vite"

# Check ports
ss -tlnp | grep -E "8080|3000"
```

If any of these fail, go back to Step 3 and run the complete reset.
