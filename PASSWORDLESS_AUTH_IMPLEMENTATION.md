# Passwordless Authentication with mTLS + MFA

**Goal**: Complete passwordless authentication using client certificates and mandatory TOTP MFA

**Status**: Implementation in progress

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                     AUTHENTICATION FLOW                          │
└──────────────────────────────────────────────────────────────────┘

1. User accesses https://jumpserver.local
   ↓
2. Browser presents mTLS client certificate
   ↓
3. nginx validates certificate against CA
   ↓
4. nginx extracts cert info → passes to Django via headers:
   - X-SSL-Client-Cert
   - X-SSL-Client-DN
   - X-SSL-Client-Serial
   ↓
5. Django MTLSAuthenticationMiddleware:
   - Verifies cert in pki_certificate table
   - Gets user from pki_certificate.user
   - Logs user in (creates django_session)
   ↓
6. Check MFA status:
   - If users_user.otp_secret_key is empty → Redirect to /setup-mfa
   - If users_user.otp_secret_key exists → Redirect to /mfa-challenge
   ↓
7. User completes MFA → django_session.mfa_verified = True
   ↓
8. Access granted to dashboard
```

---

## Database Tables & Operations

### Table 1: `pki_certificateauthority`
**Purpose**: Root CA certificate for signing user certificates

| Operation | When | Fields Modified |
|-----------|------|-----------------|
| INSERT | System init (once) | `private_key`, `certificate`, `serial_number` |
| SELECT | Every cert generation | Read `private_key` to sign new certs |

**Created by**: Management command `python manage.py create_ca`

---

### Table 2: `pki_certificate`
**Purpose**: Store all issued user certificates

| Field | Type | Purpose |
|-------|------|---------|
| `id` | UUID | Primary key |
| `user` | ForeignKey(users_user) | Certificate owner |
| `common_name` | CharField | Username from cert |
| `serial_number` | CharField | Unique cert serial |
| `certificate` | TextField | PEM-encoded cert |
| `private_key` | TextField | PEM-encoded private key |
| `not_before` | DateTime | Cert valid from |
| `not_after` | DateTime | Cert expiry date |
| `is_revoked` | Boolean | Revocation status |
| `revoked_at` | DateTime | When revoked |
| `created_by` | ForeignKey(users_user) | Admin who issued cert |

**Operations**:
| Operation | When | SQL Query |
|-----------|------|-----------|
| INSERT | Admin creates user | `INSERT INTO pki_certificate (user, serial_number, certificate...) VALUES (...)` |
| SELECT | Every login | `SELECT * FROM pki_certificate WHERE serial_number=? AND is_revoked=FALSE` |
| UPDATE | Admin revokes cert | `UPDATE pki_certificate SET is_revoked=TRUE WHERE id=?` |

---

### Table 3: `users_user`
**Purpose**: User accounts with MFA settings

**MFA-Related Fields**:
| Field | Type | Purpose |
|-------|------|---------|
| `mfa_level` | SmallInt | 0=Disabled, 1=Enabled, 2=Force |
| `otp_secret_key` | CharField | TOTP secret (base32) |

**Operations**:
| Operation | When | Fields Modified | SQL |
|-----------|------|-----------------|-----|
| SELECT | Every request | Check `otp_secret_key` | `SELECT mfa_level, otp_secret_key FROM users_user WHERE id=?` |
| UPDATE | First MFA setup | `otp_secret_key`, `mfa_level` | `UPDATE users_user SET otp_secret_key=?, mfa_level=2 WHERE id=?` |

**Flow**:
1. User logs in with cert → Check `otp_secret_key`
2. If `NULL` or empty → `/setup-mfa` page
3. User scans QR code → POST `/api/v1/authentication/mfa/setup/`
4. Backend writes: `UPDATE users_user SET otp_secret_key='ABC123...', mfa_level=2`

---

### Table 4: `django_session`
**Purpose**: Track logged-in sessions and MFA verification

**Session Data** (JSON in `session_data` field):
```json
{
  "_auth_user_id": "user-uuid-here",
  "mfa_verified": true,
  "mfa_verified_at": "2025-11-10T15:30:00Z"
}
```

**Operations**:
| Operation | When | Purpose |
|-----------|------|---------|
| INSERT | mTLS auth successful | Create session, user logged in |
| UPDATE | MFA verified | Set `mfa_verified=true` in session data |
| SELECT | Every request | Check if user authenticated |
| DELETE | Logout or expiry | End session |

---

## API Endpoints Created

### 1. MFA Setup (Enrollment)

**GET `/api/v1/authentication/mfa/setup/`**
- **Permission**: Authenticated user (via mTLS cert)
- **Database Reads**: `users_user` (check existing `otp_secret_key`)
- **Database Writes**: None (secret stored in session temporarily)
- **Returns**:
  ```json
  {
    "secret": "JBSWY3DPEHPK3PXP",
    "qr_code": "data:image/png;base64,iVBORw0KG...",
    "instructions": "Scan with Google Authenticator"
  }
  ```

**POST `/api/v1/authentication/mfa/setup/`**
- **Permission**: Authenticated user
- **Body**: `{ "code": "123456" }`
- **Database Writes**:
  ```sql
  UPDATE users_user
  SET otp_secret_key = 'JBSWY3DPEHPK3PXP',
      mfa_level = 2
  WHERE id = 'user-uuid';
  ```
- **Returns**:
  ```json
  {
    "success": true,
    "message": "MFA configured successfully"
  }
  ```

---

### 2. MFA Verification

**POST `/api/v1/authentication/mfa/verify-totp/`**
- **Permission**: Authenticated user (logged in via cert, but MFA not verified yet)
- **Body**: `{ "code": "123456" }`
- **Database Reads**:
  ```sql
  SELECT otp_secret_key FROM users_user WHERE id = 'user-uuid';
  ```
- **Database Writes**: Session update
  ```sql
  UPDATE django_session
  SET session_data = jsonb_set(session_data, '{mfa_verified}', 'true')
  WHERE session_key = 'abc123...';
  ```
- **Returns**:
  ```json
  {
    "success": true,
    "message": "MFA verification successful"
  }
  ```

---

### 3. MFA Status Check

**GET `/api/v1/authentication/mfa/status/`**
- **Permission**: Authenticated user
- **Database Reads**: `users_user.mfa_level`, `users_user.otp_secret_key`
- **Returns**:
  ```json
  {
    "mfa_configured": true,
    "mfa_required": true,
    "mfa_verified": false,
    "needs_setup": false
  }
  ```

---

## Files Created So Far

✅ **Backend**:
1. `apps/authentication/api/mfa_setup.py` - MFA setup API views
2. `apps/authentication/urls/api_urls.py` - Added MFA routes
3. `apps/authentication/api/__init__.py` - Export MFA views

---

## Files Still To Create

### Backend (Django):

**1. mTLS Authentication Middleware**
- File: `apps/authentication/middleware_mtls.py`
- Purpose: Authenticate users via certificate
- Database Operations:
  - `SELECT * FROM pki_certificate WHERE serial_number=? AND is_revoked=FALSE`
  - `SELECT * FROM users_user WHERE id=certificate.user_id`
  - `INSERT INTO django_session` (via Django auth.login())

**2. Certificate Generation Management Command**
- File: `apps/pki/management/commands/issue_user_cert.py`
- Purpose: Generate user certificate from CA
- Database Operations:
  - `SELECT private_key FROM pki_certificateauthority WHERE id=1`
  - `INSERT INTO pki_certificate (user, serial_number, certificate, private_key, ...)`

**3. Certificate Download API**
- File: `apps/pki/api/certificate.py`
- Endpoint: `GET /api/v1/pki/certificates/{id}/download/`
- Purpose: Download cert as .p12 file for browser import
- Database: `SELECT * FROM pki_certificate WHERE id=?`

**4. User Admin Modifications**
- File: `apps/users/admin.py`
- Purpose: Auto-generate cert when creating user
- Database: Calls certificate generation → INSERT into `pki_certificate`

---

### Frontend (React):

**5. MFA Setup Page**
- File: `frontend/src/pages/MFASetup.jsx`
- Purpose: Show QR code, verify TOTP code
- API Calls:
  - `GET /api/v1/authentication/mfa/setup/`
  - `POST /api/v1/authentication/mfa/setup/`

**6. Update MFA Challenge Page**
- File: `frontend/src/pages/MFAChallenge.jsx` (modify existing)
- Purpose: Verify TOTP code on each login
- API Call: `POST /api/v1/authentication/mfa/verify-totp/`

**7. Update AuthContext**
- File: `frontend/src/contexts/AuthContext.jsx` (modify existing)
- Purpose: Handle cert-based auth flow
- Changes:
  - Remove password login logic
  - Add MFA setup check
  - Redirect flow: Check MFA status → Setup or Challenge

---

### Configuration:

**8. nginx mTLS Configuration**
- File: `/etc/nginx/sites-available/jumpserver`
- Purpose: Enable client certificate verification
- Changes:
  ```nginx
  ssl_client_certificate /opt/truefypjs/data/certs/ca.crt;
  ssl_verify_client on;
  ssl_verify_depth 1;

  location / {
    proxy_set_header X-SSL-Client-Cert $ssl_client_cert;
    proxy_set_header X-SSL-Client-DN $ssl_client_s_dn;
    proxy_set_header X-SSL-Client-Serial $ssl_client_serial;
    proxy_pass http://127.0.0.1:8080;
  }
  ```

---

## Complete User Flow (After Implementation)

### Phase 1: Admin Creates User

```
1. Admin logs into Django admin: http://192.168.148.154:8080/admin
2. Admin → Users → Add User
   - Username: "investigator1"
   - Name: "John Investigator"
   - Role: Blockchain Investigator
   - Click "Save"

Database Operations:
   INSERT INTO users_user (username, name, ...) VALUES ('investigator1', ...);
   [Auto-trigger cert generation]
   INSERT INTO pki_certificate (user_id, serial_number, certificate, private_key, ...)
   VALUES ('user-uuid', '1001', '-----BEGIN CERTIFICATE-----...', ...);

3. Admin sees "Download Certificate" button
4. Admin clicks → Downloads "investigator1.p12" file
```

---

### Phase 2: User Installs Certificate

```
Windows:
1. Double-click investigator1.p12
2. Click "Install Certificate"
3. Select "Current User" → Next
4. Enter password (if set) → Next
5. Select "Place all certificates in Trusted Root"
6. Finish

Browser (Chrome/Edge):
Certificates auto-imported from Windows cert store

Browser (Firefox):
Settings → Privacy & Security → View Certificates →
Import → Select .p12 file
```

---

### Phase 3: User First Login

```
1. User navigates to: https://192.168.148.154

2. nginx requests client certificate
   - Browser shows certificate selection dialog
   - User selects "investigator1" certificate

3. nginx validates certificate:
   ✓ Signed by trusted CA
   ✓ Not expired
   ✓ Not revoked

4. nginx passes to Django:
   X-SSL-Client-Serial: 1001

5. MTLSAuthenticationMiddleware runs:
   Database Query:
   SELECT u.* FROM users_user u
   JOIN pki_certificate c ON c.user_id = u.id
   WHERE c.serial_number = '1001' AND c.is_revoked = FALSE;

   Result: user = investigator1

6. Django logs user in:
   INSERT INTO django_session (session_key, session_data, ...)
   VALUES ('abc123', '{"_auth_user_id": "user-uuid"}', ...);

7. Django checks MFA status:
   SELECT otp_secret_key FROM users_user WHERE id = 'user-uuid';

   Result: otp_secret_key = NULL (not configured)

8. Django redirects to: /setup-mfa
```

---

### Phase 4: MFA Setup

```
1. User sees page: "Setup Multi-Factor Authentication"
   - QR code displayed
   - "Scan with Google Authenticator"

2. Frontend calls: GET /api/v1/authentication/mfa/setup/
   Backend:
   - Generates random secret: "JBSWY3DPEHPK3PXP"
   - Creates QR code with URI: otpauth://totp/investigator1@JumpServer?secret=JBSWY3...
   - Stores secret in session (temporary, not in DB yet)

3. User opens Google Authenticator app
4. User scans QR code
5. App shows 6-digit code: "123456"

6. User enters code in form, clicks "Verify"
7. Frontend calls: POST /api/v1/authentication/mfa/setup/ {"code": "123456"}

8. Backend verifies code:
   totp = pyotp.TOTP("JBSWY3DPEHPK3PXP")
   is_valid = totp.verify("123456")  # Returns True

9. Backend saves to database:
   UPDATE users_user
   SET otp_secret_key = 'JBSWY3DPEHPK3PXP',
       mfa_level = 2
   WHERE id = 'user-uuid';

10. Backend responds: {"success": true}
11. Frontend redirects to: /mfa-challenge
```

---

### Phase 5: MFA Verification (Every Login)

```
1. User sees page: "Enter Authentication Code"
   - Input field for 6-digit code

2. User checks Google Authenticator: "654321"
3. User enters code, clicks "Submit"

4. Frontend calls: POST /api/v1/authentication/mfa/verify-totp/ {"code": "654321"}

5. Backend verifies:
   SELECT otp_secret_key FROM users_user WHERE id = 'user-uuid';
   Result: "JBSWY3DPEHPK3PXP"

   totp = pyotp.TOTP("JBSWY3DPEHPK3PXP")
   is_valid = totp.verify("654321")  # Returns True

6. Backend updates session:
   UPDATE django_session
   SET session_data = '{"_auth_user_id": "user-uuid", "mfa_verified": true}'
   WHERE session_key = 'abc123';

7. Backend responds: {"success": true}
8. Frontend redirects to: /dashboard

9. User now has full access!
```

---

### Phase 6: Subsequent Logins

```
1. User visits https://192.168.148.154
2. Browser auto-presents certificate (no prompt)
3. nginx validates → passes to Django
4. MTLSAuthenticationMiddleware logs user in
5. Checks MFA status:
   - otp_secret_key exists → Already configured
   - session.mfa_verified = False → Need to verify
6. Redirects to: /mfa-challenge
7. User enters current TOTP code
8. MFA verified → Dashboard access
```

---

## Security Notes

### For Admin (Yubikey Implementation)

**Current**: Admin uses same TOTP MFA as other users

**Future** (when you get Yubikey):
1. Add `yubikey_otp_id` field to `users_user`
2. Create Yubikey verification endpoint
3. Check if user is admin → require Yubikey instead of TOTP
4. Update admin login flow to use Yubikey OTP

**Database Changes** (future):
```sql
ALTER TABLE users_user ADD COLUMN yubikey_otp_id VARCHAR(12) NULL;

-- When admin logs in:
SELECT yubikey_otp_id FROM users_user WHERE id=? AND is_superuser=TRUE;
-- If yubikey_otp_id exists → require Yubikey verification
```

---

## Next Steps

1. ✅ Create MFA setup API endpoints
2. ⏳ Create mTLS middleware
3. ⏳ Create certificate generation command
4. ⏳ Create certificate download API
5. ⏳ Modify user admin for auto-cert generation
6. ⏳ Create frontend MFA Setup page
7. ⏳ Update frontend MFA Challenge page
8. ⏳ Update AuthContext for cert flow
9. ⏳ Configure nginx with mTLS
10. ⏳ Test complete flow

---

**Current Status**: MFA setup API created. Next: Create mTLS middleware.
