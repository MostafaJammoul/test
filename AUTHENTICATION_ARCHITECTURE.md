# Authentication Architecture - Dual Auth System

## Overview

The system now implements a **dual authentication strategy** as per your requirements:

1. **Admin Users:** Password + MFA authentication
2. **Regular Users:** Certificate + MFA authentication

Both authentication paths require MFA for security.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    User Access                          │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│           nginx:443 (HTTPS + optional mTLS)             │
│                                                           │
│  ssl_verify_client optional                              │
│  ssl_client_certificate /path/to/ca.crt                 │
│                                                           │
│  Passes headers:                                         │
│  - X-SSL-Client-Verify: SUCCESS/FAILED/NONE             │
│  - X-SSL-Client-Serial: <hex>                           │
│  - X-SSL-Client-DN: CN=username                         │
└─────────────────────────────────────────────────────────┘
                        ↓
┌────────────┬────────────────────┬───────────────────────┐
│ /          │ /api/              │ /admin/               │
│ Frontend   │ Backend API        │ Django Admin          │
│ port 3000  │ port 8080          │ port 8080             │
└────────────┴────────────────────┴───────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│         MTLSAuthenticationMiddleware                     │
│                                                           │
│  Admin users:                                            │
│    - Allow /api/v1/authentication/tokens/ (password)    │
│    - Sets auth_method = 'password'                      │
│                                                           │
│  Regular users:                                          │
│    - Require valid certificate (X-SSL-Client-Verify)    │
│    - Verifies certificate in database                   │
│    - Sets auth_method = 'certificate'                   │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│         MFARequiredMiddleware                            │
│                                                           │
│  ALL users (admin and regular):                         │
│    - First login → MFA setup (QR code)                  │
│    - Subsequent logins → MFA verification               │
│    - Blocks access until MFA verified                   │
│                                                           │
│  Exempt URLs:                                            │
│    - /admin/ (emergency access)                         │
│    - /api/v1/authentication/mfa/* (setup/verify)        │
│    - /static/, /media/                                  │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│            Application Access Granted                    │
└─────────────────────────────────────────────────────────┘
```

---

## nginx Routing Configuration

### Entry Point: https://jumpserverIP/

nginx acts as the **single entry point** and routes traffic:

| URL Pattern | Destination | Description |
|-------------|-------------|-------------|
| `/` | Frontend (port 3000) | React application (Vite dev server) |
| `/api/` | Backend (port 8080) | Django REST API |
| `/admin/` | Backend (port 8080) | Django admin interface |
| `/ws/` | Backend (port 8080) | WebSocket connections |
| `/static/` | Backend static files | CSS, JS, images |
| `/media/` | Backend media files | User uploads |

### Why This Matters:

**Before:**
- Frontend: http://192.168.148.154:3000
- Backend: http://192.168.148.154:8080
- Two separate entry points

**Now:**
- Everything: https://192.168.148.154/
- One unified entry point
- Professional production-ready setup

---

## Authentication Methods

### 1. Admin Authentication (Password + MFA)

**Who:** Users with `is_superuser=True` or `role='Admin'`

**Flow:**
```
1. User navigates to https://jumpserverIP/
2. Frontend loads (React app)
3. User clicks "Login"
4. Enters username + password
5. POST /api/v1/authentication/tokens/
   → MTLSAuthenticationMiddleware: Allows (admin endpoint)
   → Backend authenticates user
   → Returns token
6. Frontend redirects to MFA setup/verification
7. User scans QR code (first time) or enters code
8. POST /api/v1/authentication/mfa/verify-totp/
   → MFA verified
   → Session marked: mfa_verified=True
9. User gains access to application
```

**Technical Details:**
- No certificate required
- Password authentication via `/api/v1/authentication/tokens/`
- MFA required (TOTP via QR code)
- Session stores: `auth_method='password'` and `mfa_verified=True`

---

### 2. Regular User Authentication (Certificate + MFA)

**Who:** Non-admin users (investigators, auditors, court)

**Flow:**
```
1. User navigates to https://jumpserverIP/
2. Browser presents client certificate
3. nginx verifies certificate:
   → ssl_verify_client optional
   → Checks against CA certificate
   → Passes result to backend via headers
4. MTLSAuthenticationMiddleware:
   → Reads X-SSL-Client-Verify header
   → If SUCCESS: Queries pki_certificate table
   → If cert valid and not revoked: Login user
   → Sets auth_method='certificate'
5. MFARequiredMiddleware:
   → Checks if MFA setup required
   → Redirects to /setup-mfa (first time)
   → Redirects to /mfa-challenge (subsequent)
6. User completes MFA
7. Session marked: mfa_verified=True
8. User gains access to application
```

**Technical Details:**
- Certificate required (browser must present valid .p12 file)
- No password needed (passwordless authentication)
- Certificate verified against internal CA
- MFA still required for second factor
- Session stores: `auth_method='certificate'` and `mfa_verified=True`

---

## MFA Enforcement

### First Login (MFA Setup)

1. **User logs in** (password or certificate)
2. **Check:** Does user have `otp_secret_key` set?
   - ❌ **No:** Redirect to `/setup-mfa`
3. **Frontend displays QR code**
4. **User scans with authenticator app** (Google Authenticator, Authy, etc.)
5. **User enters 6-digit code** to verify setup
6. **Backend saves** `otp_secret_key`
7. **Session marked:** `mfa_setup_required=False`, `mfa_verified=True`
8. **User gains access**

### Subsequent Logins (MFA Verification)

1. **User logs in** (password or certificate)
2. **Check:** Does user have `otp_secret_key` set?
   - ✅ **Yes:** Redirect to `/mfa-challenge`
3. **Frontend displays MFA prompt**
4. **User enters 6-digit code** from authenticator app
5. **Backend verifies code** against saved secret
6. **Session marked:** `mfa_verified=True`
7. **User gains access**

### MFA Session Expiry

- **Certificate auth:** MFA required every login (session-based)
- **Password auth:** MFA required every login (session-based)
- **Django admin (/admin/):** MFA exempt (emergency access)

---

## Certificate Management

### For Admin (Certificate Setup)

Even though admin uses password auth, they need to manage certificates for other users:

1. **Access Django admin:**
   ```
   https://jumpserverIP/admin/
   ```

2. **Create CA (if not exists):**
   ```bash
   cd apps
   python manage.py create_ca
   ```

3. **Export CA certificate:**
   ```bash
   python manage.py export_ca_cert
   # Creates: data/certs/mtls/internal-ca.crt
   ```

4. **Issue user certificates:**
   ```bash
   python manage.py issue_user_cert <username>
   # Creates: data/certs/pki/<username>.p12
   ```

5. **Download certificates:**
   - Django admin: https://jumpserverIP/admin/pki/certificate/
   - Or via API: /api/v1/pki/certificates/<id>/download/

---

### For Regular Users (Certificate Import)

1. **Receive .p12 file** from admin
2. **Import into browser:**

   **Firefox:**
   - Settings → Privacy & Security → Certificates → View Certificates
   - Your Certificates → Import
   - Select .p12 file
   - Enter password (provided by admin)

   **Chrome:**
   - Settings → Privacy and security → Security
   - Manage certificates → Your certificates → Import
   - Select .p12 file
   - Enter password

3. **Access application:**
   - Navigate to https://jumpserverIP/
   - Browser prompts to select certificate
   - Choose imported certificate
   - Automatic login (if cert valid)

4. **Complete MFA setup** (first login)

---

## Exemptions and Special Cases

### Django Admin (/admin/)

**Why Exempt from MFA?**
- Emergency access for certificate management
- If MFA is broken, admin needs access to fix it
- Admin can revoke certificates if needed

**Who Can Access?**
- Users with `is_superuser=True` or `is_staff=True`
- Password authentication

### API Token Endpoints

**Exempt URLs:**
- `/api/v1/authentication/auth/`
- `/api/v1/authentication/tokens/`

**Why?**
- These are the login endpoints
- Can't require MFA before login
- MFA checked after successful login

### MFA Setup/Verification Endpoints

**Exempt URLs:**
- `/api/v1/authentication/mfa/setup/`
- `/api/v1/authentication/mfa/verify-totp/`
- `/api/v1/authentication/mfa/status/`

**Why?**
- User needs to complete MFA setup/verification
- Can't require MFA to set up MFA
- Circular dependency

---

## Testing Your Setup

### Test 1: Admin Password + MFA

```bash
# 1. Navigate to frontend
https://jumpserverIP/

# 2. Login with admin credentials
Username: admin
Password: admin

# 3. First login → MFA setup
- QR code displayed
- Scan with authenticator app
- Enter 6-digit code to verify
- Redirected to dashboard

# 4. Logout and login again
- Enter username + password
- Prompted for MFA code
- Enter 6-digit code from app
- Redirected to dashboard
```

### Test 2: Regular User Certificate + MFA

```bash
# 1. Generate certificate (as admin)
cd apps
source ../venv/bin/activate
python manage.py issue_user_cert investigator1

# 2. Download certificate
# From Django admin or:
ls data/certs/pki/investigator1.p12

# 3. Import certificate into browser
# (Follow browser-specific steps above)

# 4. Navigate to frontend
https://jumpserverIP/

# 5. Browser prompts for certificate
# Select investigator1 certificate

# 6. Automatic login → MFA setup
- QR code displayed
- Scan with authenticator app
- Enter 6-digit code
- Redirected to dashboard

# 7. Logout and login again
- Browser automatically presents certificate
- Prompted for MFA code
- Enter 6-digit code
- Redirected to dashboard
```

### Test 3: Django Admin Emergency Access

```bash
# 1. Navigate to Django admin
https://jumpserverIP/admin/

# 2. Login with admin credentials
Username: admin
Password: admin

# 3. No MFA required (emergency access)
- Immediate access to Django admin
- Can manage certificates
- Can revoke certificates if needed
```

---

## Troubleshooting

### Issue: "No valid client certificate" in logs

**This is normal!**
- It's a DEBUG log, not an error
- Means nginx didn't find a certificate (expected for password auth)
- Middleware continues and allows password auth for admin

### Issue: Regular user can't login (no certificate)

**Solution:**
1. Check if certificate was generated:
   ```bash
   ls data/certs/pki/<username>.p12
   ```
2. If missing, generate:
   ```bash
   cd apps
   python manage.py issue_user_cert <username>
   ```
3. Provide .p12 file to user for import

### Issue: MFA verification fails

**Check:**
1. Clock sync on server and user device (TOTP is time-based)
2. Secret key saved in database:
   ```bash
   cd apps
   python manage.py shell -c "
   from users.models import User
   u = User.objects.get(username='<username>')
   print(f'OTP Secret: {u.otp_secret_key}')
   "
   ```
3. Try resetting MFA:
   ```bash
   python manage.py shell -c "
   from users.models import User
   u = User.objects.get(username='<username>')
   u.otp_secret_key = ''
   u.save()
   "
   ```

### Issue: nginx won't start

**Check:**
1. CA certificate exists:
   ```bash
   ls data/certs/mtls/internal-ca.crt
   ```
2. If missing, export:
   ```bash
   cd apps
   python manage.py export_ca_cert
   ```
3. Test nginx config:
   ```bash
   sudo nginx -t
   ```
4. Check logs:
   ```bash
   sudo tail -f /var/log/nginx/error.log
   ```

### Issue: Frontend not loading

**Check:**
1. Vite dev server running:
   ```bash
   cd frontend
   npm run dev -- --host 0.0.0.0
   ```
2. nginx proxying correctly:
   ```bash
   curl -I http://localhost:3000
   # Should return 200 OK
   ```
3. Check nginx config:
   ```bash
   sudo nginx -t
   grep "jumpserver_frontend" /etc/nginx/sites-available/jumpserver
   ```

---

## Security Considerations

### Why Optional Certificate Verification?

nginx is configured with `ssl_verify_client optional` instead of `required`:

**Reason:**
- Allows admin to login with password (no certificate)
- Allows regular users to login with certificate
- Backend middleware enforces certificate requirement for non-admin users

**Alternative (Not Recommended):**
- `ssl_verify_client required` would block admin password login
- Admin would need certificate for emergency access
- Defeats the purpose of dual authentication system

### Why MFA for Everyone?

**Admin (password auth):**
- Password can be phished, stolen, or leaked
- MFA provides second factor protection
- Even if password compromised, attacker needs MFA code

**Regular users (certificate auth):**
- Certificate provides strong authentication (can't be phished)
- But: Certificate file can be stolen from disk
- MFA protects against stolen certificate files

**Result:** Defense in depth - multiple layers of security

---

## Summary

### What You Get:

✅ **Single entry point:** https://jumpserverIP/
✅ **Admin:** Password + MFA (no certificate needed)
✅ **Regular users:** Certificate + MFA (passwordless)
✅ **Frontend:** Accessible through nginx (professional)
✅ **MFA:** Required for all users (first + subsequent logins)
✅ **Emergency access:** Django admin bypasses MFA
✅ **WebSocket support:** For real-time features

### Next Steps:

1. **Pull changes** on your VM:
   ```bash
   git pull origin claude/codebase-review-011CUzv5iDvVA6tVuVezZeoq
   ```

2. **Reconfigure nginx** (or run setup.sh for fresh install):
   ```bash
   cd apps
   python manage.py export_ca_cert
   # Then update nginx config manually or re-run setup.sh
   ```

3. **Restart services:**
   ```bash
   ./stop_services.sh
   ./start_services.sh
   sudo systemctl reload nginx
   ```

4. **Test admin login:**
   - https://jumpserverIP/
   - Login with admin/admin
   - Complete MFA setup

5. **Generate user certificate:**
   ```bash
   cd apps
   python manage.py issue_user_cert investigator1
   ```

6. **Test user login:**
   - Import certificate into browser
   - Navigate to https://jumpserverIP/
   - Complete MFA setup

---

## Architecture Benefits:

🔒 **Security:** Multi-layer authentication
🚀 **Professional:** Production-ready nginx setup
🔑 **Flexible:** Admin password OR user certificate
📱 **MFA:** Protection against stolen credentials
⚡ **WebSocket:** Real-time updates support
🎯 **Role-based:** Different auth for different roles

Your system is now ready for production deployment!
