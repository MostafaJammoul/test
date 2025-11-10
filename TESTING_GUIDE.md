# Testing Guide - Complete Workflow

This guide walks you through testing the complete JumpServer Blockchain Chain of Custody application after running `setup.sh`.

## Prerequisites

1. Fresh installation completed via `./setup.sh`
2. Both backend and frontend services started

## Quick Start

```bash
# Run setup (if not already done)
./setup.sh

# Start both services
./start_services.sh
```

The script will automatically start:
- **Backend**: http://192.168.148.154:8080
- **Frontend**: http://192.168.148.154:3000

---

## Test Workflow

### Step 1: Access the Application

1. Open your browser
2. Navigate to: **http://192.168.148.154:3000**
3. You should see the login page

### Step 2: Login with Superuser Credentials

**Default Credentials** (from setup.sh):
- Username: `admin`
- Password: `admin`

**Actions:**
1. Enter username and password
2. Click "Sign in"
3. You should be redirected automatically

### Step 3: MFA Setup (First Login)

Since this is the first login, you'll be redirected to MFA setup:

1. **You'll see a QR code** on the MFA Setup page
2. **Open an authenticator app** on your phone:
   - Google Authenticator (iOS/Android)
   - Authy (iOS/Android)
   - Microsoft Authenticator
   - Any TOTP-compatible app

3. **Scan the QR code** with your authenticator app
4. **Enter the 6-digit code** from your authenticator app
5. **Click "Verify and Complete Setup"**

**Expected Result:** You should be redirected to the Dashboard

### Step 4: Test Admin Dashboard Features

1. Click on the "**Admin Dashboard**" link in the navbar
2. You'll see tabs for: Overview, Users, Tags, Certificates

### Step 5: Test Tag Management

1. Click the "**Tags**" tab
2. Click "**Create Tag**"
3. Fill in tag details and create
4. Verify tag appears in list
5. Test delete functionality

### Step 6: Test User Management

1. Click the "**Users**" tab
2. View existing users
3. Click "**Create User**" to see the form
4. Test user deactivation

### Step 7: Test Certificate Download

1. Click the "**Certificates**" tab
2. Click "**Download**" button next to admin certificate
3. Verify .p12 file downloads

---

## Verification Checklist

- [ ] Login works
- [ ] MFA setup completes
- [ ] Dashboard accessible
- [ ] Admin dashboard accessible
- [ ] Can create/delete tags
- [ ] Can view users
- [ ] Can download certificates

**Happy Testing!** 🎉
