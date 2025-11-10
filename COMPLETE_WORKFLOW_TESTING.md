# Complete Workflow Testing Guide

**Date**: 2025-11-10
**System**: JumpServer Blockchain Chain of Custody
**Features**: Password Login + mTLS + Mandatory MFA

---

## ✅ All Fixes Applied

### What Was Fixed

1. **✅ Login Page Created** - Password authentication now available at `/login`
2. **✅ AuthContext Updated** - Handles both password and certificate auth
3. **✅ setup.sh Fully Automatic** - No manual prompts, creates CA → Superuser → Certificate
4. **✅ Middleware Updated** - Django admin allows password auth without mTLS
5. **✅ MFA Optional for Password Auth** - Only required for certificate users

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Access Methods                            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Password Auth (Development)        mTLS Auth (Production)   │
│  ├─ Frontend: http://localhost:3000 ├─ nginx: https://...    │
│  ├─ Login page with username/password├─ Certificate required │
│  ├─ MFA setup (first time)          ├─ MFA setup (required)  │
│  └─ MFA challenge (subsequent)      └─ MFA challenge         │
│                                                               │
│  Django Admin (Both)                                          │
│  ├─ URL: http://localhost:8080/admin                          │
│  ├─ Password auth only                                        │
│  └─ No MFA required                                           │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Automatic Setup (No Manual Steps!)

### Step 1: Run setup.sh

```bash
cd /opt/truefypjs
./setup.sh
```

**What happens automatically**:
1. ✅ Purges all databases (PostgreSQL, MySQL, Redis)
2. ✅ Installs system dependencies
3. ✅ Creates PostgreSQL database
4. ✅ Creates Python virtual environment
5. ✅ Installs Python packages (including pyotp, qrcode)
6. ✅ Runs database migrations
7. ✅ Creates builtin roles (including blockchain roles)
8. ✅ **Creates Certificate Authority (CA)**
9. ✅ **Creates superuser automatically**:
   - Username: `bakri` (or set `SUPERUSER_USERNAME` env var)
   - Password: `Admin@123` (or set `SUPERUSER_PASSWORD` env var)
   - Email: `admin@jumpserver.local`
10. ✅ **Auto-generates certificate for bakri** (via Django signal)
11. ✅ Configures nginx
12. ✅ Starts Django backend on port 8080

**Default Credentials**:
- Username: `bakri`
- Password: `Admin@123`
- ⚠️ **Change this immediately after first login!**

### Step 2: Start Frontend (Separate Terminal)

```bash
cd /opt/truefypjs/frontend
npm install
npm run dev -- --host 0.0.0.0
```

Frontend runs on: **http://192.168.148.154:3000**

---

## Complete Workflow Test (Password Login)

###  Test 1: First-Time Login with Password

**URL**: `http://192.168.148.154:3000/login`

1. **Login Page Displays** ✅
   - Username field
   - Password field
   - "Sign in" button

2. **Enter Credentials**:
   - Username: `bakri`
   - Password: `Admin@123`
   - Click "Sign in"

3. **Backend Processes** (Check Django logs):
   ```
   POST /api/v1/authentication/auth/
   - Creates session for bakri
   - Sets auth_method='password' in session
   ```

4. **Redirected to MFA Setup** ✅
   - URL: `/setup-mfa`
   - QR code displayed
   - Manual entry secret key shown

5. **Scan QR Code**:
   - Open Google Authenticator (or Authy) on mobile
   - Tap "+" to add account
   - Scan QR code
   - App shows "JumpServer Blockchain - bakri"
   - 6-digit code appears (refreshes every 30 seconds)

6. **Enter TOTP Code**:
   - Copy current 6-digit code from app
   - Enter in web page
   - Click "Verify and Enable MFA"

7. **Backend Processes**:
   ```
   POST /api/v1/authentication/mfa/setup/
   - Verifies TOTP code
   - UPDATE users_user SET otp_secret_key='...', mfa_level=2 WHERE username='bakri'
   - Redirects to /mfa-challenge
   ```

8. **MFA Challenge Page** ✅
   - URL: `/mfa-challenge`
   - Prompt for 6-digit code

9. **Enter Current TOTP Code**:
   - Get current code from app
   - Enter code
   - Click "Verify"

10. **Backend Processes**:
    ```
    POST /api/v1/authentication/mfa/verify-totp/
    - Verifies code
    - UPDATE django_session SET mfa_verified=true
    - Redirects to /dashboard
    ```

11. **Dashboard Displays** ✅
    - URL: `/dashboard` or `/admin-dashboard` (for bakri as admin)
    - Full access to system
    - Can create users, view certificates, manage investigations

**✅ First login workflow complete!**

---

### Test 2: Subsequent Login (MFA Already Configured)

1. **Logout** (or close browser)

2. **Navigate to**: `http://192.168.148.154:3000/login`

3. **Login**:
   - Username: `bakri`
   - Password: `Admin@123`

4. **Redirected Directly to MFA Challenge** ✅
   - URL: `/mfa-challenge`
   - No QR code (already configured)

5. **Enter Current TOTP Code**:
   - Get from authenticator app
   - Verify

6. **Dashboard Access** ✅

**✅ Subsequent login workflow complete!**

---

### Test 3: Django Admin Access (No MFA Required)

**URL**: `http://192.168.148.154:8080/admin/`

1. **Login**:
   - Username: `bakri`
   - Password: `Admin@123`

2. **Django Admin Dashboard** ✅
   - Direct access, no MFA prompt
   - Can manage users, view PKI certificates, configure system

**Why no MFA?**
- Middleware checks `auth_method` in session
- If `auth_method != 'certificate'`, MFA is skipped
- Django admin uses password auth, not certificates

**✅ Django admin access verified!**

---

### Test 4: Create New User and Certificate

**From Django Admin** (`http://192.168.148.154:8080/admin/`):

1. **Navigate to Users**:
   - Click "Users" in sidebar
   - Click "Add User" button

2. **Fill User Details**:
   - Username: `investigator1`
   - Name: `John Investigator`
   - Email: `john@example.com`
   - Click "Save"

3. **Auto-Certificate Generation** ✅
   - Django signal `auto_generate_certificate` triggers
   - Certificate automatically created
   - Database operations:
     ```sql
     INSERT INTO users_user (username, name, email, ...)
     -- Signal triggers:
     INSERT INTO pki_certificate (user_id, serial_number, certificate, private_key, ...)
     UPDATE pki_certificateauthority SET serial_number = serial_number + 1
     ```

4. **Verify Certificate Creation**:
   - Navigate to: **PKI → Certificates**
   - Find certificate for `investigator1`
   - Should see:
     - User: investigator1
     - Serial Number: (auto-generated)
     - Status: Active
     - Created: (current timestamp)

5. **Download Certificate**:
   - Click on the certificate
   - Click "Download .p12 file" button
   - File `investigator1.p12` downloads

**✅ User creation and auto-certificate generation verified!**

---

### Test 5: Certificate-Based Login (mTLS via nginx)

**Prerequisites**:
1. nginx configured and running
2. Certificate downloaded and installed in browser

**URL**: `https://192.168.148.154` (via nginx, port 443)

1. **Browser Prompts for Certificate** ✅
   - Certificate selection dialog appears
   - Shows "bakri@jumpserver" certificate

2. **Select Certificate**:
   - Choose bakri's certificate
   - Click OK

3. **nginx Validates Certificate**:
   - Checks against CA
   - Verifies not revoked
   - Passes headers to Django:
     ```
     X-SSL-Client-Verify: SUCCESS
     X-SSL-Client-Serial: 1000
     X-SSL-Client-DN: CN=bakri,O=JumpServer Blockchain,C=PS
     ```

4. **Django MTLSAuthenticationMiddleware**:
   ```python
   # Query: SELECT * FROM pki_certificate WHERE serial_number='1000' AND is_revoked=FALSE
   # Finds certificate → Gets user → Logs in
   # Sets auth_method='certificate' in session
   ```

5. **Redirect to MFA Challenge** ✅
   - URL: `/mfa-challenge`
   - MFA required for certificate auth

6. **Enter TOTP Code**:
   - Verify with authenticator app

7. **Dashboard Access** ✅

**✅ mTLS authentication verified!**

---

## Testing Checklist

### Backend Setup
- [ ] setup.sh runs without errors
- [ ] PostgreSQL database created
- [ ] All migrations applied
- [ ] CA created successfully
- [ ] Superuser created automatically (bakri/Admin@123)
- [ ] Certificate auto-generated for bakri
- [ ] Django admin accessible

### Frontend Setup
- [ ] npm install completes
- [ ] npm run dev starts frontend on port 3000
- [ ] Login page accessible at /login

### Password Authentication Flow
- [ ] Login page displays correctly
- [ ] Can login with bakri/Admin@123
- [ ] Redirected to /setup-mfa on first login
- [ ] QR code displays
- [ ] Can scan QR with authenticator app
- [ ] TOTP verification works
- [ ] Redirected to /mfa-challenge
- [ ] MFA challenge accepts valid code
- [ ] Dashboard loads after MFA
- [ ] Admin dashboard accessible (for bakri)

### Subsequent Login
- [ ] Login redirects directly to /mfa-challenge (skips /setup-mfa)
- [ ] TOTP code verification works
- [ ] Dashboard accessible

### Django Admin
- [ ] Can access /admin with password
- [ ] No MFA prompt for admin access
- [ ] Can create new users
- [ ] Can view PKI certificates
- [ ] Can download certificates

### User Creation & Certificate Management
- [ ] Creating user auto-generates certificate
- [ ] Certificate appears in PKI admin
- [ ] Can download certificate as .p12
- [ ] Serial numbers increment correctly
- [ ] Can view certificate details

### mTLS Authentication (via nginx)
- [ ] nginx configured and running
- [ ] https://192.168.148.154 accessible
- [ ] Browser prompts for certificate
- [ ] Certificate authentication works
- [ ] MFA required after cert auth
- [ ] Dashboard accessible after MFA

### Role-Based Access
- [ ] Admin sees admin dashboard
- [ ] Can assign blockchain roles to users
- [ ] Different roles see different dashboards

---

## URLs Reference

| Service | URL | Auth Method | MFA Required |
|---------|-----|-------------|--------------|
| Frontend Login | http://192.168.148.154:3000/login | Password | After setup |
| Frontend Dev | http://192.168.148.154:3000 | Auto-redirect | - |
| Django Admin | http://192.168.148.154:8080/admin | Password | No |
| Django API | http://192.168.148.154:8080/api/v1/ | Both | Yes (cert) |
| nginx Production | https://192.168.148.154 | Certificate | Yes |

---

## Expected Database State After Setup

### pki_certificateauthority
```
id  | name                | serial_number | is_active
----|---------------------|---------------|----------
uuid| JumpServer Root CA  | 1001          | true
```

### pki_certificate
```
id  | user     | serial_number | is_revoked | cert_type
----|----------|---------------|------------|----------
uuid| bakri    | 1000          | false      | user
```

### users_user
```
username | otp_secret_key | mfa_level | is_superuser
---------|----------------|-----------|-------------
bakri    | (32 char key)  | 2         | true
```

---

## Troubleshooting

### Issue: Login page doesn't load
**Check**:
```bash
# Frontend running?
curl http://localhost:3000

# Check console for errors
# Browser dev tools → Console
```

### Issue: "Invalid credentials" on login
**Check**:
```bash
cd /opt/truefypjs/apps
source ../venv/bin/activate
python manage.py shell
>>> from users.models import User
>>> u = User.objects.get(username='bakri')
>>> print(f"Username: {u.username}, Active: {u.is_active}")
>>> u.check_password('Admin@123')  # Should return True
```

### Issue: QR code doesn't display
**Check**:
```bash
# Is qrcode package installed?
pip list | grep qrcode

# Check Django logs
tail -f data/logs/jumpserver.log
```

### Issue: "MFA verification failed"
**Causes**:
1. **Clock skew** - Check system time matches
2. **Wrong code** - Wait for new code (codes refresh every 30 seconds)
3. **Secret not saved** - Check database

### Issue: Certificate auth not working
**Check nginx**:
```bash
sudo nginx -t
sudo systemctl status nginx
curl -k https://localhost
```

---

## Environment Variables (Optional)

Customize setup by setting these before running setup.sh:

```bash
export SUPERUSER_USERNAME="admin"      # Default: bakri
export SUPERUSER_PASSWORD="MyPass123"  # Default: Admin@123
export SUPERUSER_EMAIL="admin@example.com"  # Default: admin@jumpserver.local

./setup.sh
```

---

## Success Criteria

✅ **Setup Complete** when:
- All backend services running (PostgreSQL, Redis, Django)
- Frontend accessible at port 3000
- Can login with password
- MFA setup works
- Dashboard accessible
- Can create users in Django admin
- Certificates auto-generate for new users

✅ **System Ready** when:
- Password login flow works end-to-end
- MFA enforced for certificate users
- Django admin accessible
- User creation and certificate management working
- All blockchain features accessible

---

**Status**: ✅ All components ready for testing

Follow the test cases above to verify complete functionality.
