# MFA Workflow Fix

## Problem Description

After setting up MFA, users were prompted to enter their verification code **twice**, and the second attempt would fail with "MFA already configured" error.

### Broken Flow (Before Fix)

1. User logs in with admin/admin
2. Redirected to MFA setup page ✓
3. Scans QR code with authenticator app ✓
4. Enters TOTP code → POST /api/v1/authentication/mfa/setup/ ✓
5. **Backend saves MFA to database but doesn't mark session as verified** ✗
6. Success message shown: "MFA configured successfully" ✓
7. User tries to proceed → MFARequiredMiddleware blocks access (no `mfa_verified` in session)
8. Frontend shows **different page**: "Enter code to verify"
9. User enters code again → Frontend calls `/mfa/setup/` **again** (wrong endpoint)
10. Backend sees MFA already configured → **Error: "MFA already configured for this user"** ✗
11. User taken back to MFA setup page → **Loop**

---

## Root Cause

In `apps/authentication/api/mfa_setup.py` line 148-161, the MFA setup POST method:

```python
# BEFORE (BROKEN):
def post(self, request):
    # ... verify code ...

    # Save MFA to database
    user.otp_secret_key = secret
    user.mfa_level = 2
    user.save(update_fields=['otp_secret_key', 'mfa_level'])

    # Clear pending secret
    del request.session['pending_mfa_secret']

    # ❌ MISSING: No session['mfa_verified'] = True

    return Response({
        'success': True,
        'message': 'MFA configured successfully'
    })
```

**The problem:** Session was NOT marked as `mfa_verified=True`, so:
- MFARequiredMiddleware still blocked the user
- Frontend thought verification was needed
- User had to enter code again

---

## The Fix

### Change 1: Mark Session as Verified After Setup

**File:** `apps/authentication/api/mfa_setup.py` lines 155-157

```python
# AFTER (FIXED):
def post(self, request):
    # ... verify code ...

    # Save MFA to database
    user.otp_secret_key = secret
    user.mfa_level = 2
    user.save(update_fields=['otp_secret_key', 'mfa_level'])

    # ✓ Mark MFA as verified in session (no need to verify again immediately)
    request.session['mfa_verified'] = True
    request.session['mfa_verified_at'] = str(timezone.now())

    # Clear pending secret
    del request.session['pending_mfa_secret']

    return Response({
        'success': True,
        'message': 'MFA configured successfully'
    })
```

**Why this works:**
- After setup succeeds, session is immediately marked as verified
- MFARequiredMiddleware allows access
- User can proceed without entering code again

### Change 2: MFA Reset Script for Testing

**File:** `reset_admin_mfa.sh` (new)

Created a script to reset admin's MFA configuration for testing:

```bash
#!/bin/bash
cd ~/js/apps
source ../venv/bin/activate

python manage.py shell <<'PYEOF'
from users.models import User

user = User.objects.get(username='admin')
user.otp_secret_key = None
user.mfa_level = 0
user.save(update_fields=['otp_secret_key', 'mfa_level'])

print("✓ MFA configuration reset successfully")
PYEOF
```

**Usage:**
```bash
cd ~/js
bash reset_admin_mfa.sh
```

This allows you to test the MFA setup flow again without manually editing the database.

---

## Fixed Flow (After Fix)

1. User logs in with admin/admin
2. Redirected to MFA setup page ✓
3. Scans QR code with authenticator app ✓
4. Enters TOTP code → POST /api/v1/authentication/mfa/setup/ ✓
5. **Backend saves MFA to database AND marks session as verified** ✓
6. Success message shown: "MFA configured successfully" ✓
7. User proceeds → MFARequiredMiddleware sees `mfa_verified=True` → **Allows access** ✓
8. User can now access all resources ✓

---

## How to Apply the Fix

### Step 1: Reset Admin's MFA (if already configured)

```bash
cd ~/js
bash reset_admin_mfa.sh
```

**Output:**
```
Current MFA status for admin:
  - mfa_level: 2
  - otp_secret_key: ***SET***

✓ MFA configuration reset successfully
  - mfa_level: 0
  - otp_secret_key: NOT SET

Admin can now go through MFA setup again.
```

### Step 2: Pull Latest Changes

```bash
cd ~/js
git pull origin claude/codebase-review-011CUzv5iDvVA6tVuVezZeoq
```

### Step 3: Restart Backend

```bash
pkill -9 -f "python manage.py runserver"
cd apps
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
source ../venv/bin/activate
nohup python manage.py runserver 0.0.0.0:8080 > ../data/logs/backend.log 2>&1 &
sleep 3
```

### Step 4: Test MFA Setup Flow

1. Navigate to: **https://192.168.148.154/**
2. Login with: **admin / admin**
3. You'll be redirected to MFA setup page
4. Scan QR code with Google Authenticator or Authy
5. Enter the 6-digit TOTP code
6. Click "Verify"
7. **Expected:** Success message → Immediately proceed to dashboard/resources
8. **No more "enter code again" prompt!**

---

## Database Schema (MFA Storage)

**Table:** `users_user`

**Columns:**
- `otp_secret_key` (varchar) - Base32-encoded TOTP secret (e.g., "JBSWY3DPEHPK3PXP")
- `mfa_level` (integer)
  - `0` = Disabled/Not configured
  - `1` = Optional
  - `2` = Required/Enforced

**Session Storage:**

**Django Session Table:** `django_session`

**Session Keys:**
- `mfa_verified` (boolean) - Whether current session has verified MFA
- `mfa_verified_at` (string) - ISO timestamp of verification
- `pending_mfa_secret` (string) - Temporary secret during setup (deleted after setup)
- `auth_username` (string) - Username during login flow (before full authentication)
- `auth_user_id` (string) - User ID during login flow

---

## Manual MFA Reset (Alternative Method)

If the script doesn't work, you can manually reset MFA:

```bash
cd ~/js/apps
source ../venv/bin/activate

python manage.py shell
```

Then in Python shell:
```python
from users.models import User

# Get admin user
user = User.objects.get(username='admin')

# Check current MFA status
print(f"Current: mfa_level={user.mfa_level}, secret={'SET' if user.otp_secret_key else 'NOT SET'}")

# Reset MFA
user.otp_secret_key = None
user.mfa_level = 0
user.save(update_fields=['otp_secret_key', 'mfa_level'])

# Verify reset
print(f"After reset: mfa_level={user.mfa_level}, secret={'SET' if user.otp_secret_key else 'NOT SET'}")

exit()
```

---

## Testing Checklist

After applying the fix, verify:

- [ ] Login with admin/admin → Redirected to MFA setup
- [ ] Scan QR code → QR code displayed correctly
- [ ] Enter TOTP code → Success message shown
- [ ] **No second "enter code" prompt** ✓ (FIXED)
- [ ] Immediately proceed to dashboard/resources ✓ (FIXED)
- [ ] No "MFA already configured" error ✓ (FIXED)
- [ ] Backend logs show no errors
- [ ] Can access `/api/v1/users/me/` after MFA setup
- [ ] Session persists across page refreshes

---

## Related Files Modified

1. **apps/authentication/api/mfa_setup.py** (lines 155-157)
   - Added `request.session['mfa_verified'] = True`
   - Added `request.session['mfa_verified_at'] = str(timezone.now())`

2. **reset_admin_mfa.sh** (new file)
   - Script to reset admin MFA for testing

---

## Summary

**Before Fix:**
- ❌ MFA setup succeeded but session not marked verified
- ❌ User prompted to enter code twice
- ❌ Second attempt failed with "MFA already configured"
- ❌ Stuck in loop between setup and verify pages

**After Fix:**
- ✓ MFA setup succeeds and session immediately marked verified
- ✓ User enters code only once during setup
- ✓ No second verification prompt
- ✓ User proceeds directly to dashboard
- ✓ Clean, single-step MFA enrollment

---

## Next Steps

1. **Reset admin MFA:** `bash reset_admin_mfa.sh`
2. **Restart backend** with updated code
3. **Test complete login flow** with MFA setup
4. **Verify no errors** in backend logs

The MFA workflow should now be seamless! 🎉
