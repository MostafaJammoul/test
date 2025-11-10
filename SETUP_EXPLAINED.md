# JumpServer Setup Script - Explained

## Quick Answers to Your Questions

### Q1: Is setup.sh fully inclusive for a fresh clone?

**YES** - After I created the `sync_role` management command, `setup.sh` is now fully inclusive. Your friend can:

```bash
# On a fresh Ubuntu VM
git clone <your-repo>
cd truefypjs
chmod +x setup.sh
./setup.sh
```

Everything will be configured automatically:
- ✅ System dependencies installed (PostgreSQL, Redis, nginx, etc.)
- ✅ Python virtual environment created
- ✅ Database created and migrations run
- ✅ PKI/CA initialized
- ✅ **Blockchain roles synced** (FIXED - now works with the new management command)
- ✅ Superuser created
- ✅ User certificate issued
- ✅ nginx configured with mTLS
- ✅ Server ready to run

---

### Q2: Should you run setup.sh again after VM restart?

**NO** - Do NOT run `setup.sh` again after rebooting. Here's what happens:

#### What IS Permanent (Survives Reboots):
✅ **PostgreSQL database** - All data persists in `/var/lib/postgresql/`
  - User accounts
  - Investigations
  - Evidence records
  - Blockchain transactions
  - Certificates
  - Roles and permissions

✅ **Configuration files** - Remain in your project directory
  - `config.yml`
  - `data/certs/mtls/*` (CA certs, server certs, user certs)
  - nginx configuration at `/etc/nginx/sites-available/jumpserver-mtls`

✅ **Installed packages** - System dependencies stay installed
  - PostgreSQL, Redis, nginx, Python packages

✅ **Virtual environment** - Python packages remain in `venv/`

#### What is NOT Permanent (Stops on Reboot):
❌ **Running processes** - These stop when VM shuts down:
  - Django development server (port 8080)
  - nginx (usually auto-restarts, but check)
  - PostgreSQL (usually auto-restarts via systemd)
  - Redis (usually auto-restarts via systemd)

---

### Q3: What to do after VM restart?

After turning on your VM, just start the services:

```bash
# 1. Navigate to project directory
cd /opt/truefypjs  # or wherever you cloned it

# 2. Check services are running (they should auto-start)
sudo systemctl status postgresql  # Should be active
sudo systemctl status redis        # Should be active
sudo systemctl status nginx        # Should be active

# 3. If any service is not running, start it:
sudo systemctl start postgresql
sudo systemctl start redis
sudo systemctl start nginx

# 4. Activate virtual environment
source venv/bin/activate

# 5. Start Django backend
cd apps
python manage.py runserver 0.0.0.0:8080

# Keep this terminal open!
```

That's it! Your database, users, and configurations are all preserved.

---

## What setup.sh Does (Step by Step)

### One-Time Setup Steps (Don't repeat):
1. ✅ Install system packages (PostgreSQL, Redis, nginx, build tools)
2. ✅ Create PostgreSQL database and user
3. ✅ Create Python virtual environment
4. ✅ Install Python dependencies
5. ✅ Create data directories
6. ✅ Generate SECRET_KEY and BOOTSTRAP_TOKEN in config.yml
7. ✅ Run database migrations
8. ✅ Initialize PKI (create Internal CA)
9. ✅ Export CA certificate for nginx
10. ✅ Generate server SSL certificate
11. ✅ Configure nginx for mTLS
12. ✅ **Sync builtin roles** (NOW WORKS - Fixed!)
13. ✅ Create superuser (interactive)
14. ✅ Issue user certificate
15. ✅ Collect static files

### What Happens if You Run setup.sh Again?

The script is **mostly idempotent** (safe to re-run), but:

#### Safe to Re-run:
- ✅ System package installation (apt will skip if installed)
- ✅ Database creation (skips if exists)
- ✅ Virtual environment (reuses if exists)
- ✅ Migrations (only applies new ones)
- ✅ PKI initialization (safe - checks if CA exists)
- ✅ Certificate export (overwrites)
- ✅ nginx configuration (overwrites)
- ✅ Role sync (updates roles, safe)
- ✅ Static file collection (overwrites)

#### NOT Safe to Re-run:
- ⚠️ **Superuser creation** - Will fail if user already exists (error: "User with that username already exists")
- ⚠️ **Certificate issuance** - May overwrite existing user certificates

**Recommendation**: Don't re-run `setup.sh` unless you're starting completely fresh. Use `fix_setup.sh` instead for repairs.

---

## Persistence Details

### Database Storage

All JumpServer data is stored in **PostgreSQL**, which persists data to disk:

**Location**: `/var/lib/postgresql/14/main/` (version may vary)

**What's stored**:
- `users_user` table - User accounts, passwords (hashed)
- `pki_certificateauthority` table - Internal CA certificate (encrypted)
- `pki_certificate` table - User certificates (encrypted)
- `rbac_role` table - Roles (Admin, Investigator, Auditor, Court, etc.)
- `rbac_system_role_binding` table - User-role assignments
- `blockchain_investigation` table - Investigations
- `blockchain_evidence` table - Evidence metadata
- `blockchain_blockchaintransaction` table - Blockchain transaction records
- `blockchain_guidmapping` table - GUID to user ID mappings (encrypted)

**Backup PostgreSQL**:
```bash
# Backup
pg_dump -U jumpserver -d jumpserver > jumpserver_backup.sql

# Restore
psql -U jumpserver -d jumpserver < jumpserver_backup.sql
```

---

### Certificate Storage

Certificates are stored in **two places**:

#### 1. Database (Primary, Encrypted)
- **Table**: `pki_certificateauthority` - CA cert + private key (encrypted)
- **Table**: `pki_certificate` - User certs + private keys (encrypted)
- **Encryption**: AES-256, key derived from Django SECRET_KEY

#### 2. Filesystem (Exported for nginx)
- **CA cert**: `data/certs/mtls/internal-ca.crt` (public, for nginx)
- **CA CRL**: `data/certs/mtls/internal-ca.crl` (public, revocation list)
- **Server SSL**: `data/certs/mtls/server.crt` and `server.key` (for nginx HTTPS)
- **User P12**: `data/certs/pki/<username>.p12` (exported for browser import)

**Why two places?**
- Database = Source of truth, encrypted, backed up with database
- Filesystem = nginx can't read from database, needs files

**Backup certificates**:
```bash
# Backup entire data directory
tar -czf jumpserver_certs_backup.tar.gz data/certs/

# Or just user certificates
tar -czf user_certs_backup.tar.gz data/certs/pki/*.p12
```

---

### Configuration Files

**Permanent files** (in your project directory):

1. **`config.yml`** - Main configuration
   - SECRET_KEY (generated once)
   - BOOTSTRAP_TOKEN (generated once)
   - Database credentials
   - Blockchain settings

2. **`/etc/nginx/sites-available/jumpserver-mtls`** - nginx config
   - Server SSL certificate paths
   - Client CA certificate path
   - Proxy settings

3. **`data/` directory** - Runtime data
   - `data/certs/` - Certificates
   - `data/logs/` - Log files (not permanent, rotates)
   - `data/media/` - Uploaded files
   - `data/static/` - Static assets (regenerated with collectstatic)
   - `data/uploads/` - Evidence files (mock IPFS storage)

**Backup these**:
```bash
# Backup entire project (excluding venv)
cd /opt
tar --exclude='truefypjs/venv' \
    --exclude='truefypjs/data/logs' \
    -czf jumpserver_project_backup.tar.gz truefypjs/
```

---

## Error You Encountered: `sync_role` Not Found

### The Problem

Line 368 of `setup.sh`:
```bash
cd apps && python manage.py sync_role
```

**Error**: `Unknown command: 'sync_role'`

**Why**: JumpServer's original codebase synchronizes roles through **database migrations**, not a management command. The migration file [0003_auto_20211130_1037.py](truefypjs/apps/rbac/migrations/0003_auto_20211130_1037.py:11) calls:

```python
BuiltinRole.sync_to_db(show_msg=True)
```

But there was no standalone management command for `sync_role`.

### The Fix

I created the missing management command:

**New file**: [`apps/rbac/management/commands/sync_role.py`](apps/rbac/management/commands/sync_role.py)

```python
from django.core.management.base import BaseCommand
from rbac.builtin import BuiltinRole

class Command(BaseCommand):
    help = 'Sync builtin roles (including blockchain roles) to the database'

    def handle(self, *args, **options):
        BuiltinRole.sync_to_db(show_msg=True)
```

Now `python manage.py sync_role` works! ✅

---

## Running for the First Time (Your Friend's Clean VM)

### Prerequisites
- Ubuntu 20.04 or later
- Internet connection (for package downloads)
- At least 4GB RAM, 20GB disk

### Steps

```bash
# 1. Clone repository
git clone <your-repo-url>
cd truefypjs

# 2. Run setup script
chmod +x setup.sh
./setup.sh

# This will:
# - Install all dependencies (~10 minutes)
# - Create database
# - Initialize PKI
# - Sync blockchain roles ✅ (FIXED!)
# - Prompt for superuser creation (interactive)
# - Issue certificate
# - Configure nginx
# - Start Django server automatically

# 3. Access JumpServer
# HTTPS with mTLS: https://<vm-ip>/
# HTTP direct: http://<vm-ip>:8080/
```

### What to Provide to Your Friend

1. **Repository URL** (GitHub, GitLab, etc.)
2. **This documentation** (SETUP_EXPLAINED.md)
3. **Optional**: Pre-configured `config.yml` with your preferred settings

That's it! One command setup.

---

## Daily Usage (After Setup)

### Morning (VM Start):

```bash
# SSH to VM
ssh jsroot@192.168.148.154

# Navigate to project
cd /opt/truefypjs

# Check services (usually auto-start)
sudo systemctl status postgresql nginx redis

# Start Django backend
source venv/bin/activate
cd apps
python manage.py runserver 0.0.0.0:8080
```

### Evening (VM Shutdown):

```bash
# Stop Django (Ctrl+C in the terminal)
# Optionally stop services (but systemd will auto-restart them):
sudo systemctl stop nginx  # Optional
```

That's it! No need to re-run setup.sh.

---

## Production Deployment (Optional)

For production use, instead of running `setup.sh` every time you restart:

### 1. Create systemd service for Django

**File**: `/etc/systemd/system/jumpserver.service`

```ini
[Unit]
Description=JumpServer Django Backend
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=jsroot
WorkingDirectory=/opt/truefypjs/apps
Environment="PATH=/opt/truefypjs/venv/bin"
ExecStart=/opt/truefypjs/venv/bin/python manage.py runserver 0.0.0.0:8080
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### 2. Enable and start service

```bash
sudo systemctl daemon-reload
sudo systemctl enable jumpserver.service
sudo systemctl start jumpserver.service

# Check status
sudo systemctl status jumpserver.service
```

Now JumpServer will **auto-start on boot**! 🎉

---

## Troubleshooting

### Database Not Found After Reboot

```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# If not running:
sudo systemctl start postgresql

# Verify database exists
sudo -u postgres psql -l | grep jumpserver
```

### Certificates Missing After Reboot

Certificates should **not disappear** after reboot. If they do:

```bash
# Re-export from database (database is source of truth)
cd /opt/truefypjs
source venv/bin/activate
cd apps
python manage.py export_ca_cert --output ../data/certs/mtls/internal-ca.crt
python manage.py export_crl --output ../data/certs/mtls/internal-ca.crl
```

### nginx Not Working After Reboot

```bash
# Check nginx status
sudo systemctl status nginx

# If not running:
sudo systemctl start nginx

# Check for errors:
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

---

## Summary

| Question | Answer |
|----------|--------|
| **Run setup.sh on fresh clone?** | ✅ YES - Fully automated (after sync_role fix) |
| **Run setup.sh after reboot?** | ❌ NO - Just start Django server |
| **Is database permanent?** | ✅ YES - Stored in `/var/lib/postgresql/` |
| **Are certificates permanent?** | ✅ YES - Stored in database + `data/certs/` |
| **Are configs permanent?** | ✅ YES - `config.yml` and nginx config persist |
| **What stops on reboot?** | Django server (you must restart it) |
| **What auto-restarts?** | PostgreSQL, Redis, nginx (via systemd) |

**TLDR**: Setup once, then just start Django after reboots. Everything else is permanent.

---

**End of SETUP_EXPLAINED.md**
