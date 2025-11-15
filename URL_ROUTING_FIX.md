# URL Routing Fix - /api/v1/users/me/ Endpoint

## Problem Summary

The frontend was calling `/api/v1/users/me/` but getting 404 errors, even though the URL pattern was added to the code.

## Root Cause

**URL Pattern Duplication:**
- Main URLs (`apps/jumpserver/urls.py` line 18): `path('users/', include('users.urls.api_urls'))`
- Users API URLs (`apps/users/urls/api_urls.py` line 24): `path('users/me/', ...)`

This created: `/api/v1/users/users/me/` ❌ (double "users")
Frontend expected: `/api/v1/users/me/` ✓ (single "users")

## What Changed

**File:** `apps/users/urls/api_urls.py` (line 24)

**Before:**
```python
path('users/me/', api.UserProfileApi.as_view(), name='user-me'),
```

**After:**
```python
path('me/', api.UserProfileApi.as_view(), name='user-me'),
```

**Why:** Since the main URL already includes `'users/'`, the pattern should just be `'me/'` to avoid duplication.

---

## How to Fix Without Running setup.sh

### Step 1: Pull the Latest Changes

```bash
cd ~/js  # or your repository directory
git pull origin claude/codebase-review-011CUzv5iDvVA6tVuVezZeoq
```

### Step 2: Kill All Backend Processes

```bash
# Kill all runserver processes
pkill -9 -f "python manage.py runserver"

# Verify all killed
ps aux | grep "python manage.py runserver" | grep -v grep
# Should return nothing
```

### Step 3: Clear Django Cache

```bash
cd ~/js/apps
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
```

### Step 4: Restart Backend

```bash
cd ~/js/apps
source ../venv/bin/activate
nohup python manage.py runserver 0.0.0.0:8080 > ../data/logs/backend.log 2>&1 &

# Wait for server to start
sleep 3
```

### Step 5: Test the Endpoint

**Option A: Quick Test (without authentication)**
```bash
curl http://localhost:8080/api/v1/users/me/
# Should return: {"detail":"Authentication credentials were not provided."}
# This confirms the endpoint exists (401 means auth required, not 404)
```

**Option B: Full Test (with authentication)**
```bash
# Get auth token
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/authentication/tokens/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' | \
  grep -o '"token":"[^"]*"' | cut -d'"' -f4)

# Test endpoint with token
curl -X GET http://localhost:8080/api/v1/users/me/ \
  -H "Authorization: Bearer $TOKEN"

# Should return user profile JSON with username, role, etc.
```

### Step 6: Test Frontend Login

```bash
# Make sure frontend is running
cd ~/js/frontend
npm run dev -- --host 0.0.0.0

# Open browser: http://192.168.148.154:3000
# Login with: admin / admin
# Should successfully load user profile
```

---

## Alternative: Use the Diagnostic Script

I created a comprehensive diagnostic script that does all the above automatically:

```bash
cd ~/js
chmod +x fix_url_routing.sh
bash fix_url_routing.sh
```

This script will:
1. Check for multiple backend processes
2. Kill all runserver processes
3. Clear Django cache and bytecode
4. Verify URL patterns are loaded
5. Restart backend
6. Test the endpoint
7. Show diagnostic information

---

## Verification Checklist

After following the steps above, verify:

- [ ] `curl http://localhost:8080/api/v1/users/me/` returns 401 (not 404)
      ✓ Means endpoint exists, just needs authentication

- [ ] Backend logs show no 404 for `/api/v1/users/me/`
      Check: `tail -f ~/js/data/logs/backend.log`

- [ ] Frontend login works and loads user profile
      ✓ No console errors about "users/me" 404

- [ ] Password authentication works
      ✓ Already confirmed with your test: "Password authentication NOW WORKS!"

---

## Why This Happened

1. **Initial Implementation:** Added `path('users/me/', ...)` without considering the parent URL already had `'users/'`
2. **URL Structure in Django:** When you use `include()`, the parent path is prepended to all child paths
3. **Pattern:**
   - Parent: `/api/v1/users/`
   - Child: `users/me/`
   - Result: `/api/v1/users/users/me/` ❌

**Correct Pattern:**
   - Parent: `/api/v1/users/`
   - Child: `me/`
   - Result: `/api/v1/users/me/` ✓

---

## Related Fixes Already Applied

### Issue 1: Missing --output Argument in CA Certificate Export
**Commit:** `57d50361`
**Fix:** Added `--output ../data/certs/mtls/internal-ca.crt --force` to export_ca_cert command in setup.sh

### Issue 2: Empty CRL File
**Commit:** `14943511`
**Fix:** Removed `ssl_crl` directive from nginx config (CRL not implemented yet)

### Issue 3: Corrupted GeoLite2 Database
**Manual Fix Required:**
```bash
rm -f apps/common/utils/ip/geoip/GeoLite2-City.mmdb
bash ./requirements/static_files.sh
cp apps/common/utils/ip/geoip/GeoLite2-City.mmdb data/system/
```

### Issue 4: Password Hash Incorrect
**Manual Fix Applied:**
```bash
cd ~/js/apps
source ../venv/bin/activate
python manage.py shell -c "
from users.models import User
user = User.objects.get(username='admin')
user.set_password('admin')
user.is_superuser = True
user.is_staff = True
user.is_active = True
user.role = 'Admin'
user.save()
"
```
**Status:** ✓ Confirmed working ("Password authentication NOW WORKS!")

### Issue 5: URL Routing (Current Fix)
**Commit:** `50f4d344`
**Fix:** Changed URL pattern from `'users/me/'` to `'me/'`

---

## Summary

**Before Fix:**
- ❌ Frontend: GET /api/v1/users/me/ → 404 Not Found
- ❌ Django: No URL pattern matches
- ❌ Login fails because profile can't be loaded

**After Fix:**
- ✓ Frontend: GET /api/v1/users/me/ → 200 OK (with auth) or 401 (without auth)
- ✓ Django: URL pattern matches correctly
- ✓ Login succeeds and user profile loads

---

## Next Steps

1. **Pull changes:** `git pull origin claude/codebase-review-011CUzv5iDvVA6tVuVezZeoq`
2. **Restart backend:** Follow steps above
3. **Test login:** http://192.168.148.154:3000 with admin/admin
4. **Verify user profile loads** in frontend

If you encounter any issues, run the diagnostic script:
```bash
bash fix_url_routing.sh
```

Login should now work end-to-end! 🎉
