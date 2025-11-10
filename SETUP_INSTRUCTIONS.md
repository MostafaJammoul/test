# Complete Setup Instructions - JumpServer Blockchain Chain of Custody

**Last Updated**: 2025-11-10
**Status**: ✅ Ready for deployment (PKI migration fix applied)

---

## Quick Start (TL;DR)

```bash
# 1. Transfer code to VM
cd C:\Users\mosta\Desktop\FYP\JumpServer
scp -r truefypjs/* jsroot@192.168.148.154:/opt/truefypjs/

# 2. SSH into VM and run setup
ssh jsroot@192.168.148.154
cd /opt/truefypjs
chmod +x setup.sh
./setup.sh

# Script will:
# - Purge all databases (PostgreSQL, MySQL, Redis)
# - Install dependencies
# - Run migrations (PKI fix included)
# - Create superuser
# - Start Django server
```

---

## What's New (Latest Changes)

### ✅ PKI Migration Fixed
- Fixed `KeyError: ('pki', 'certificate')` error
- [apps/pki/migrations/0001_initial.py](apps/pki/migrations/0001_initial.py) now properly creates all PKI models
- Migration creates Certificate model with `certificate_hash` field included

### ✅ UI Enhancement Models Added
- Tag (Admin creates tag library)
- InvestigationTag (Court assigns tags, max 3 per case)
- InvestigationNote (Investigator notes, blockchain-logged)
- InvestigationActivity (24-hour activity tracking)

### ✅ Complete Setup Script
- [setup.sh](setup.sh) now includes complete database purge
- Automatically cleans Redis, PostgreSQL, MySQL
- Deletes old migrations and Python cache
- Creates fresh database with all tables

---

## Prerequisites

- **VM**: Ubuntu 20.04+ (192.168.148.154)
- **User**: jsroot (with sudo access)
- **Python**: 3.11+ (script installs if missing)
- **Network**: SSH access from Windows host
- **Disk Space**: ~2GB free for dependencies

---

## Step-by-Step Guide

### 1. Transfer Code from Windows to VM

```powershell
# From Windows PowerShell
cd C:\Users\mosta\Desktop\FYP\JumpServer

# Transfer entire truefypjs directory
scp -r truefypjs/* jsroot@192.168.148.154:/opt/truefypjs/

# Set correct ownership (on VM)
ssh jsroot@192.168.148.154 "sudo chown -R jsroot:jsroot /opt/truefypjs"
```

### 2. Run Setup Script

```bash
# SSH into VM
ssh jsroot@192.168.148.154

# Navigate to project directory
cd /opt/truefypjs

# Make setup script executable
chmod +x setup.sh

# Run setup (interactive prompts will ask for confirmation)
./setup.sh
```

### 3. Follow Interactive Prompts

The script will ask:

1. **Confirmation 1**: `Type 'yes' to proceed`
   - This confirms you want to purge all databases

2. **Confirmation 2**: `Type 'DELETE EVERYTHING'`
   - Final confirmation before deletion

3. **Superuser Username**: `Enter superuser username (default: admin)`
   - Press Enter for "admin" or type custom username

4. **Superuser Password**: Django will prompt for password
   - Enter password (not shown on screen)
   - Confirm password

5. **Superuser Email**: Django will prompt for email
   - Enter email address or leave blank

### 4. What the Script Does

```
STEP 1:  Purging databases (Redis, PostgreSQL, MySQL)
STEP 2:  Checking prerequisites (Python 3.11)
STEP 3:  Installing system dependencies
STEP 4:  Setting up PostgreSQL
STEP 5:  Setting up Redis
STEP 6:  Creating virtual environment
STEP 7:  Installing Python dependencies (5-10 minutes)
STEP 8:  Creating data directories
STEP 9:  Generating secret keys
STEP 10: Setting up migrations (PKI fix applied)
STEP 11: Running database migrations ✅
STEP 12: Syncing builtin roles
STEP 13: Initializing Internal CA
STEP 14: Installing and configuring nginx
STEP 15: Collecting static files
STEP 16: Creating superuser account
STEP 17: Issuing user certificate (if PKI commands exist)
STEP 18: Verifying Django configuration
STEP 19: Starting Django server on http://localhost:8080
```

### 5. Expected Output

```
✅ SETUP COMPLETE!

Database Configuration:
  PostgreSQL:
    - Host: localhost:5432
    - Database: jumpserver
    - User: jsroot
    - Password: jsroot

  Redis:
    - Host: localhost:6379
    - Status: Flushed (fresh start)

Blockchain/IPFS Mode:
  - Mock Blockchain: ENABLED
  - Mock IPFS: ENABLED

How to Start JumpServer:
  1. Activate virtual environment:
     source venv/bin/activate

  2. Start Django backend:
     cd apps && python manage.py runserver 0.0.0.0:8080

  3. Access application:
     - Backend (direct): http://localhost:8080
     - Frontend (nginx): https://localhost

Starting JumpServer backend on http://localhost:8080...
```

---

## Post-Setup Verification

### 1. Check Database Tables

```bash
# Connect to PostgreSQL
PGPASSWORD=jsroot psql -h localhost -U jsroot -d jumpserver

# Inside psql:
\dt pki_*
# Should show: pki_certificateauthority, pki_certificate, pki_certificate_revocation_list

\dt blockchain_*
# Should show: blockchain_investigation, blockchain_evidence, blockchain_transaction,
#              blockchain_tag, blockchain_investigation_tag, blockchain_investigation_note,
#              blockchain_investigation_activity, blockchain_guid_mapping

\q
```

### 2. Check Redis

```bash
redis-cli PING
# Should return: PONG

redis-cli DBSIZE
# Should return: (integer) 0 (fresh start)
```

### 3. Check Django

```bash
cd /opt/truefypjs/apps
source ../venv/bin/activate
python manage.py check
# Should return: System check identified no issues (0 silenced).
```

### 4. Test Backend

```bash
# From Windows host, open browser:
http://192.168.148.154:8080/admin

# Login with:
# Username: admin (or what you set)
# Password: (password you set during setup)
```

---

## Manual Database Purge (Without Running Full Setup)

If you need to purge databases manually:

```bash
# See detailed commands in:
cat MANUAL_DATABASE_PURGE.md

# Quick purge script:
redis-cli FLUSHALL
sudo -u postgres psql -c "DROP DATABASE IF EXISTS jumpserver;"
sudo -u postgres psql -c "DROP USER IF EXISTS jumpserver;"
rm -rf /opt/truefypjs/venv
rm -rf /opt/truefypjs/data/*
```

**Full manual purge script**: See [MANUAL_DATABASE_PURGE.md](MANUAL_DATABASE_PURGE.md)

---

## Troubleshooting

### Error: "relation already exists"

**Cause**: Database has old tables from previous migrations

**Fix**:
```bash
# Drop database and recreate
sudo -u postgres psql -c "DROP DATABASE IF EXISTS jumpserver;"
sudo -u postgres psql -c "CREATE DATABASE jumpserver OWNER jsroot;"

# Run migrations again
cd /opt/truefypjs/apps
python manage.py migrate
```

### Error: "KeyError: ('pki', 'certificate')"

**Status**: ✅ FIXED in latest code

**What was wrong**: Old PKI migration tried to add field to non-existent model

**Fix applied**: [apps/pki/migrations/0001_initial.py](apps/pki/migrations/0001_initial.py) now creates all models

If you still see this error:
```bash
# Ensure you transferred the latest code
cd C:\Users\mosta\Desktop\FYP\JumpServer
scp truefypjs/apps/pki/migrations/0001_initial.py jsroot@192.168.148.154:/opt/truefypjs/apps/pki/migrations/
```

### Error: "cannot import name EncryptTextField"

**Cause**: Missing JumpServer dependency

**Fix**:
```bash
cd /opt/truefypjs
source venv/bin/activate
pip install -e .
```

### Error: "FATAL: Peer authentication failed for user jumpserver"

**Cause**: PostgreSQL requires password authentication

**Fix**:
```bash
# Edit pg_hba.conf
sudo nano /etc/postgresql/*/main/pg_hba.conf

# Change these lines:
local   all             all                                     peer
host    all             all             127.0.0.1/32            ident

# To:
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Redis Connection Failed

**Fix**:
```bash
# Start Redis
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Test connection
redis-cli PING
```

---

## Accessing the Application

### From VM (localhost)

```bash
# Django backend (direct)
http://localhost:8080

# nginx (SSL proxy)
https://localhost
```

### From Windows Host

```bash
# Django backend (direct)
http://192.168.148.154:8080

# nginx (SSL proxy) - requires importing self-signed cert
https://192.168.148.154
```

### Admin Panel

```
URL: http://192.168.148.154:8080/admin
Username: admin (or what you set)
Password: (password you set during setup)
```

### API Endpoints

```bash
# Health check
curl http://192.168.148.154:8080/api/health/

# List investigations
curl http://192.168.148.154:8080/api/v1/blockchain/investigations/ \
  -H "Authorization: Bearer <token>"

# List tags
curl http://192.168.148.154:8080/api/v1/blockchain/tags/

# List activities
curl http://192.168.148.154:8080/api/v1/blockchain/investigation-activities/
```

---

## Important File Locations

| File/Directory | Location | Purpose |
|---------------|----------|---------|
| Django settings | `/opt/truefypjs/apps/jumpserver/settings.py` | Main configuration |
| Config file | `/opt/truefypjs/config.yml` | Database, Redis, secrets |
| Logs | `/opt/truefypjs/data/logs/jumpserver.log` | Application logs |
| Static files | `/opt/truefypjs/data/static/` | CSS, JS, images |
| Media files | `/opt/truefypjs/data/media/` | Uploaded files |
| Evidence uploads | `/opt/truefypjs/data/uploads/` | Mock IPFS storage |
| Certificates | `/opt/truefypjs/data/certs/pki/` | User .p12 files |
| nginx config | `/etc/nginx/sites-available/jumpserver` | Reverse proxy |
| Virtual env | `/opt/truefypjs/venv/` | Python packages |

---

## Database Schema

### PKI Tables (3 tables)

```sql
pki_certificateauthority
  - id (UUID)
  - name, certificate, private_key
  - valid_from, valid_until, is_active

pki_certificate
  - id (UUID)
  - serial_number, subject_dn, issuer_dn
  - certificate, private_key, certificate_hash
  - not_before, not_after, revoked
  - ca_id (FK), user_id (FK)

pki_certificate_revocation_list
  - id (UUID)
  - crl_pem, this_update, next_update
  - ca_id (FK)
```

### Blockchain Tables (8 tables)

```sql
blockchain_investigation
  - id (UUID), case_number, title, description
  - status (active/archived)
  - created_by, archived_by, reopened_by (FKs)

blockchain_evidence
  - id (UUID), title, description
  - file_name, file_size, mime_type
  - file_hash_sha256, ipfs_cid
  - investigation_id, uploaded_by (FKs)

blockchain_transaction
  - id (UUID), transaction_hash
  - chain_type (hot/cold), block_number
  - evidence_hash, ipfs_cid, merkle_root
  - investigation_id, user_id (FKs)

blockchain_guid_mapping
  - id (UUID), guid
  - user_id (FK) - One-to-one

blockchain_tag
  - id (UUID), name, category, color
  - description, created_by (FK)

blockchain_investigation_tag
  - id (UUID)
  - investigation_id, tag_id (FKs)
  - added_by (FK)
  - Unique(investigation, tag)

blockchain_investigation_note
  - id (UUID), content, note_hash
  - blockchain_tx_hash
  - investigation_id, created_by (FKs)

blockchain_investigation_activity
  - id (UUID), activity_type, description
  - timestamp, investigation_id, performed_by (FKs)
  - viewed_by (Many-to-Many)
```

---

## Next Steps After Setup

1. **Login to Admin Panel**
   - URL: http://192.168.148.154:8080/admin
   - Create users, assign roles

2. **Test Blockchain API**
   - Create investigation
   - Upload evidence
   - Add notes
   - Assign tags

3. **Build React Frontend**
   - See [FRONTEND_COMPONENTS_REMAINING.md](FRONTEND_COMPONENTS_REMAINING.md)
   - Components ready: Badge, Button, Card, Modal, Navbar, Layout
   - Remaining: AdminDashboard, TagManagement, InvestigationList, etc.

4. **Configure Real Blockchain** (Optional)
   - Install IPFS: See DATABASE_ARCHITECTURE_EXPLAINED.md
   - Install Hyperledger Fabric: See DATABASE_ARCHITECTURE_EXPLAINED.md
   - Set `USE_MOCK_BLOCKCHAIN=False` in settings

---

## Useful Commands

```bash
# Start Django server
cd /opt/truefypjs/apps && source ../venv/bin/activate && python manage.py runserver 0.0.0.0:8080

# Django shell
cd /opt/truefypjs/apps && python manage.py shell

# Create migrations
cd /opt/truefypjs/apps && python manage.py makemigrations

# Run migrations
cd /opt/truefypjs/apps && python manage.py migrate

# Create superuser
cd /opt/truefypjs/apps && python manage.py createsuperuser

# Sync roles
cd /opt/truefypjs/apps && python manage.py sync_role

# Collect static files
cd /opt/truefypjs/apps && python manage.py collectstatic --noinput

# Check Django config
cd /opt/truefypjs/apps && python manage.py check

# View logs
tail -f /opt/truefypjs/data/logs/jumpserver.log

# Restart nginx
sudo systemctl restart nginx

# Reload nginx (without dropping connections)
sudo systemctl reload nginx
```

---

## Support Documents

- [FIX_APPLIED_README.md](FIX_APPLIED_README.md) - Explanation of PKI migration fix
- [CHANGES_APPLIED_TO_VM.md](CHANGES_APPLIED_TO_VM.md) - Detailed list of all code changes
- [MANUAL_DATABASE_PURGE.md](MANUAL_DATABASE_PURGE.md) - Manual database cleanup commands
- [DATABASE_ARCHITECTURE_EXPLAINED.md](DATABASE_ARCHITECTURE_EXPLAINED.md) - Complete database guide
- [BLOCKCHAIN_API_DOCUMENTATION.md](BLOCKCHAIN_API_DOCUMENTATION.md) - API endpoint reference
- [FRONTEND_COMPONENTS_REMAINING.md](FRONTEND_COMPONENTS_REMAINING.md) - React component guide

---

**Ready to deploy!** Just run `./setup.sh` on the VM.
