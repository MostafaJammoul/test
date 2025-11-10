# Quick Fix Guide - Current Deployment Issues

**Date**: 2025-11-10
**System**: JumpServer Blockchain Chain of Custody

---

## Issues Identified

1. **Superuser (bakri) has no certificate** - PKI system was added after superuser creation
2. **Port 3000 (frontend dev) bypasses mTLS** - Direct access without nginx causes authentication confusion
3. **Port 8080 returns JSON instead of UI** - Backend API, not meant for direct browser access
4. **MFA verification failing** - Session state inconsistency

---

## Root Cause Analysis

### Problem 1: Chicken-and-Egg Certificate Problem
- Superuser "bakri" was created before PKI signal handler was added
- Signal handler only runs for NEW users (`created=True`)
- Bakri has no certificate, can't authenticate with mTLS

### Problem 2: Development Mode Confusion
- Frontend on port 3000 (npm run dev) accessed directly, bypassing nginx
- No nginx headers (`X-SSL-Client-Serial`) present
- Previous username/password session still active, causing confusion
- MFA enforcement happening without proper authentication context

### Problem 3: API vs UI Confusion
- Port 8080 is Django REST API backend (returns JSON)
- Port 3000 is React frontend (serves UI)
- Django admin is at `http://192.168.148.154:8080/admin/` (returns HTML)
- API endpoints return JSON, not HTML pages

### Problem 4: MFA Session State
- Frontend making MFA status requests without proper certificate auth
- Session from previous password login still active
- MFA verification failing because auth context doesn't match

---

## The Fixes (Already Applied)

### Fix 1: Management Command for Existing Users ✅
**File**: [apps/pki/management/commands/generate_missing_certs.py](apps/pki/management/commands/generate_missing_certs.py)

**Purpose**: Generate certificates for users created before PKI system

**Usage**:
```bash
# For specific user (bakri)
cd /opt/truefypjs/apps
source ../venv/bin/activate
python manage.py generate_missing_certs --username bakri

# For all users without certificates
python manage.py generate_missing_certs
```

### Fix 2: Middleware Updated ✅
**File**: [apps/authentication/middleware_mtls.py](apps/authentication/middleware_mtls.py)

**Changes**:
- Django admin (`/admin/`) now allows traditional username/password authentication
- Auth method tracked in session (`auth_method`: `'password'` or `'certificate'`)
- MFA only enforced for certificate-authenticated users
- Password-authenticated users (Django admin) bypass MFA requirement

**Exempt URLs** (allow password auth):
- `/admin/` - Django admin
- `/api/v1/authentication/auth/` - Token creation
- `/api/v1/authentication/tokens/` - Legacy tokens

### Fix 3: MFA Status API Updated ✅
**File**: [apps/authentication/api/mfa_setup.py](apps/authentication/api/mfa_setup.py)

**Changes**:
- Returns different responses based on `auth_method`
- Password auth: `mfa_required: false`, `needs_setup: false`
- Certificate auth: `mfa_required: true`, `needs_setup: true/false`

### Fix 4: Setup Script Updated ✅
**File**: [setup.sh](setup.sh)

**Changes**:
- Step 13: Use `create_ca` command (not `init_pki`)
- Step 17: Use `generate_missing_certs` command (not `issue_user_cert`)
- Automatically creates certificate for superuser after user creation

---

## Current Deployment - What You Need to Do

### Step 1: Stop All Services
```bash
ssh jsroot@192.168.148.154

# Stop frontend (if running)
# Press Ctrl+C in the terminal running npm

# Stop backend (if running)
# Press Ctrl+C in the terminal running Django
```

### Step 2: Transfer Updated Files
From Windows PowerShell:
```powershell
cd C:\Users\mosta\Desktop\FYP\JumpServer

# Transfer updated files
scp truefypjs/apps/pki/management/commands/generate_missing_certs.py jsroot@192.168.148.154:/opt/truefypjs/apps/pki/management/commands/
scp truefypjs/apps/authentication/middleware_mtls.py jsroot@192.168.148.154:/opt/truefypjs/apps/authentication/
scp truefypjs/apps/authentication/api/mfa_setup.py jsroot@192.168.148.154:/opt/truefypjs/apps/authentication/api/
scp truefypjs/setup.sh jsroot@192.168.148.154:/opt/truefypjs/

# Set permissions
ssh jsroot@192.168.148.154 "sudo chown -R jsroot:jsroot /opt/truefypjs && chmod +x /opt/truefypjs/setup.sh"
```

### Step 3: Create CA (If Not Already Created)
```bash
ssh jsroot@192.168.148.154
cd /opt/truefypjs/apps
source ../venv/bin/activate

# Create CA (ignore warning if already exists)
python manage.py create_ca
```

**Expected Output**:
```
✓ Root CA created successfully
  CA ID: <uuid>
  Valid from: 2025-11-10 ...
  Valid until: 2035-11-10 ...
  Next serial: 1000
```

Or:
```
CA already exists. Use existing CA.
Existing CA ID: <uuid>
```

### Step 4: Generate Certificate for Bakri
```bash
# Still in /opt/truefypjs/apps with venv activated
python manage.py generate_missing_certs --username bakri
```

**Expected Output**:
```
Found 1 user(s) without certificates

✓ Certificate generated for bakri (ID: <uuid>, Serial: 1000)

Completed: 1 successful, 0 errors

Users can now download their certificates from:
  Django Admin: http://192.168.148.154:8080/admin/pki/certificate/
  API: http://192.168.148.154:8080/api/v1/pki/certificates/<id>/download/
```

### Step 5: Access Django Admin with Username/Password
From Windows browser:
```
http://192.168.148.154:8080/admin/
```

**Login**:
- Username: `bakri`
- Password: (your password)

**You should now see Django admin dashboard!** ✅

### Step 6: Download Bakri's Certificate
In Django admin:

1. Click **PKI** in left sidebar
2. Click **Certificates**
3. Find certificate for user "bakri"
4. Click on it
5. Click **"Download .p12 file"** button (or use the Download link)

**The browser will download** `bakri.p12`

### Step 7: Install Certificate in Windows
1. Double-click `bakri.p12` file
2. Certificate Import Wizard opens:
   - Store Location: **Current User** → Next
   - File to Import: (already selected) → Next
   - Password: (leave empty, no password) → Next
   - Certificate Store: **Automatically select** → Next
   - Finish

3. Verify installation:
   - Press `Win+R` → Type `certmgr.msc` → Enter
   - Navigate to: Personal → Certificates
   - Should see certificate with CN=bakri

### Step 8: Export CA Certificate for nginx
Still on VM:
```bash
cd /opt/truefypjs/apps
source ../venv/bin/activate

# Export CA certificate
python manage.py shell << 'EOF'
from pki.models import CertificateAuthority
ca = CertificateAuthority.objects.first()
with open('/opt/truefypjs/data/certs/ca.crt', 'w') as f:
    f.write(ca.certificate)
print("CA cert exported to /opt/truefypjs/data/certs/ca.crt")
EOF
```

### Step 9: Update nginx Configuration
```bash
# Copy our mTLS nginx config
sudo cp /opt/truefypjs/nginx_mtls.conf /etc/nginx/sites-available/jumpserver

# Enable site
sudo ln -sf /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Update paths in config
sudo sed -i 's|/opt/truefypjs/data/certs/server.crt|/opt/truefypjs/data/certs/mtls/server.crt|g' /etc/nginx/sites-available/jumpserver
sudo sed -i 's|/opt/truefypjs/data/certs/server.key|/opt/truefypjs/data/certs/mtls/server.key|g' /etc/nginx/sites-available/jumpserver

# Test configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### Step 10: Start Django Backend
Terminal 1:
```bash
cd /opt/truefypjs/apps
source ../venv/bin/activate
python manage.py runserver 0.0.0.0:8080
```

### Step 11: Start React Frontend
Terminal 2:
```bash
cd /opt/truefypjs/frontend
npm install  # If not already done
npm run dev -- --host 0.0.0.0
```

### Step 12: Test Complete Flow

**IMPORTANT**: Access via nginx (port 443), NOT directly to ports 3000 or 8080!

From Windows browser:
```
https://192.168.148.154
```

**What should happen**:
1. Browser prompts for certificate selection
2. Select "bakri" certificate
3. Click OK
4. You are redirected to `/setup-mfa` (because bakri doesn't have MFA configured yet)
5. QR code is displayed
6. Scan with Google Authenticator/Authy
7. Enter 6-digit code
8. Code is verified ✅
9. Redirected to `/mfa-challenge`
10. Enter current 6-digit code from app
11. Code verified ✅
12. Redirected to `/dashboard`
13. **You're in!** 🎉

---

## Testing Django Admin (Without Certificate)

You can still access Django admin with username/password (no certificate needed):

```
http://192.168.148.154:8080/admin/
```

Login: `bakri` / (your password)

This is useful for:
- Managing users
- Viewing/revoking certificates
- Administrative tasks
- Debugging

**MFA is NOT required for Django admin access** (traditional auth)

---

## Development Mode vs Production Mode

### Development Mode (Current Setup)
- Frontend: `http://192.168.148.154:3000` (direct, no mTLS)
- Backend: `http://192.168.148.154:8080` (direct, no mTLS)
- Django admin: `http://192.168.148.154:8080/admin/` (password auth)

**Issues**:
- No mTLS enforcement
- Direct access bypasses nginx
- MFA confusion

### Production Mode (Recommended)
- All access through nginx: `https://192.168.148.154` (mTLS enforced)
- nginx proxies to frontend (port 3000) and backend (port 8080)
- Certificate required for regular users
- Django admin still accessible with password for admins

---

## Troubleshooting

### Issue: "No certificates available" in browser
**Fix**: Certificate not installed correctly

Check Windows certificate store:
```
Win+R → certmgr.msc → Personal → Certificates
```

Should see certificate with CN=bakri

### Issue: nginx error "CA certificate not found"
**Fix**: Export CA certificate

```bash
cd /opt/truefypjs/apps
python manage.py shell
>>> from pki.models import CertificateAuthority
>>> ca = CertificateAuthority.objects.first()
>>> with open('/opt/truefypjs/data/certs/ca.crt', 'w') as f:
...     f.write(ca.certificate)
```

### Issue: "MFA verification failed"
**Possible causes**:

1. **Clock skew** - Check system time on VM:
   ```bash
   date
   # Should match your current time
   ```

2. **Wrong code** - TOTP codes refresh every 30 seconds, make sure to use current code

3. **Session issue** - Clear browser cookies and restart browser

4. **Database issue** - Check if MFA secret was saved:
   ```bash
   cd /opt/truefypjs/apps
   python manage.py shell
   >>> from users.models import User
   >>> u = User.objects.get(username='bakri')
   >>> print(f"MFA Level: {u.mfa_level}, Secret: {u.otp_secret_key}")
   ```

### Issue: Still seeing MFA setup without certificate
**Fix**: Clear browser session

The browser may have cached session from password login. Clear cookies:
- Press F12 → Application → Cookies → Delete all for this site
- Restart browser

### Issue: Django admin returns JSON instead of HTML
**Fix**: Make sure you're accessing `/admin/` (with trailing slash):

```
http://192.168.148.154:8080/admin/    ✅ Correct
http://192.168.148.154:8080/admin     ❌ Wrong
http://192.168.148.154:8080/api/...   ❌ API endpoint (returns JSON)
```

---

## Key Takeaways

1. **Django admin uses traditional auth** (username/password, no certificate needed)
2. **Regular users use mTLS + MFA** (certificate required)
3. **Always access through nginx** (port 443) for mTLS enforcement
4. **Direct access to ports 3000/8080 is for development only**
5. **Generate certificates for existing users** with `generate_missing_certs` command
6. **MFA setup is per-user, one-time** (unless regenerated)
7. **MFA verification is per-session** (required on each login)

---

## Next Steps After Fixing

1. Create additional users via Django admin
2. Certificates are auto-generated for new users (via signal handler)
3. Download and distribute certificates to users
4. Users log in with certificate + MFA
5. Full blockchain chain of custody workflow ready

---

**Status**: All fixes applied, ready for testing

Follow steps 1-12 above to resolve all current issues.
