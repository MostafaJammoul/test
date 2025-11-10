# Migration Fix Applied - Ready for SCP Transfer

**Date**: 2025-11-10
**Issue**: `KeyError: ('pki', 'certificate')` during migration
**Root Cause**: Broken PKI migration trying to add field to non-existent model

---

## Problem Explanation

The PKI app's `0001_initial.py` migration had a critical error:

**BEFORE** (Broken):
```python
class Migration(migrations.Migration):
    initial = True  # Claims to be initial migration

    operations = [
        # But tries to ADD FIELD to Certificate model that doesn't exist yet!
        migrations.AddField(
            model_name='certificate',  # ERROR: Model doesn't exist!
            name='certificate_hash',
            ...
        ),
    ]
```

**Issue**: The migration claimed to be "initial" but tried to **modify** a model instead of **creating** it. This caused Django to look for an existing `certificate` model, which didn't exist, resulting in the `KeyError`.

---

## Fix Applied

I completely rewrote [apps/pki/migrations/0001_initial.py](C:\Users\mosta\Desktop\FYP\JumpServer\truefypjs\apps\pki\migrations\0001_initial.py) to properly **create** all 3 PKI models:

1. **CertificateAuthority** - Internal CA for issuing certs
2. **Certificate** - Client certificates for mTLS (now includes `certificate_hash` field)
3. **CertificateRevocationList** - CRL for revoked certs

**AFTER** (Fixed):
```python
operations = [
    migrations.CreateModel(
        name='CertificateAuthority',
        fields=[...],
    ),
    migrations.CreateModel(
        name='Certificate',
        fields=[
            ...
            ('certificate_hash', models.CharField(...)),  # Hash field included!
        ],
    ),
    migrations.CreateModel(
        name='CertificateRevocationList',
        fields=[...],
    ),
    # Add indexes
    migrations.AddIndex(...),
]
```

---

## What Changed in Your Codebase

### Modified Files:

| File | Change |
|------|--------|
| [apps/pki/migrations/0001_initial.py](C:\Users\mosta\Desktop\FYP\JumpServer\truefypjs\apps\pki\migrations\0001_initial.py) | **Completely rewritten** - Now properly creates all PKI models |

### No Changes Needed To:

- `apps/pki/models.py` - Already correct
- `apps/blockchain/models.py` - Already has Tag, InvestigationTag, InvestigationNote, InvestigationActivity
- `apps/blockchain/migrations/0001_initial.py` - Already correct (includes all UI models)
- All other files

---

## Steps to Transfer and Migrate

### 1. Transfer to VM

From your Windows host (PowerShell):

```powershell
# Stop Django if running
ssh jsroot@192.168.148.154 "pkill -f 'python manage.py runserver'"

# Backup current VM code (optional but recommended)
ssh jsroot@192.168.148.154 "cp -r /opt/truefypjs /opt/truefypjs_backup_$(date +%Y%m%d_%H%M%S)"

# Transfer the entire truefypjs directory
cd C:\Users\mosta\Desktop\FYP\JumpServer
scp -r truefypjs/* jsroot@192.168.148.154:/opt/truefypjs/

# Set correct ownership
ssh jsroot@192.168.148.154 "sudo chown -R jsroot:jsroot /opt/truefypjs"
```

### 2. Reset Database (Fresh Start)

On the VM:

```bash
ssh jsroot@192.168.148.154
cd /opt/truefypjs/apps
source ../venv/bin/activate

# Drop and recreate database (WARNING: Deletes all data!)
python manage.py dbshell << EOF
DROP DATABASE IF EXISTS truefyp_db;
CREATE DATABASE truefyp_db OWNER truefyp_user;
\q
EOF

# Run all migrations from scratch
python manage.py migrate

# Create superuser
python manage.py createsuperuser
```

### 3. Start Django Server

```bash
# Still on VM, in /opt/truefypjs/apps with venv activated
python manage.py runserver 0.0.0.0:8080
```

---

## Expected Migration Output

When you run `python manage.py migrate`, you should see:

```
Operations to perform:
  Apply all migrations: accounts, acls, admin, assets, audits, auth, authentication, blockchain, captcha, contenttypes, django_cas_ng, django_celery_beat, labels, notifications, ops, orgs, perms, pki, rbac, sessions, settings, terminal, tickets, users

Running migrations:
  Applying pki.0001_initial... OK
  Applying blockchain.0001_initial... OK
  (... other apps ...)

After migration, update builtin role permissions
  - Update builtin roles

System check identified no issues (0 silenced).
```

**NO ERRORS** should appear.

---

## What Gets Created in Database

### PKI Tables (3 tables):
- `pki_certificate_authority` - CA records with public cert and private key
- `pki_certificate` - User/service certificates with:
  - serial_number, subject_dn, issuer_dn
  - certificate (PEM), private_key (PEM)
  - not_before, not_after, revoked status
  - **certificate_hash** (SHA-256 for reissuance prevention)
- `pki_certificate_revocation_list` - CRLs for revoked certs

### Blockchain Tables (8 tables):
- `blockchain_investigation` - Cases
- `blockchain_blockchain_transaction` - Blockchain tx records
- `blockchain_evidence` - Evidence file metadata
- `blockchain_guid_mapping` - Anonymous GUID → User mapping
- **`blockchain_tag`** - Tag library (Admin creates)
- **`blockchain_investigation_tag`** - Tag assignments (Court assigns, max 3)
- **`blockchain_investigation_note`** - Investigator notes (blockchain-logged)
- **`blockchain_investigation_activity`** - Activity feed (24h indicators)

---

## Verification Commands

After migration completes:

```bash
# Check all tables created
python manage.py dbshell -c "\dt pki_*; \dt blockchain_*;"

# Verify models can be imported
python manage.py shell << EOF
from pki.models import Certificate, CertificateAuthority, CertificateRevocationList
from blockchain.models import Investigation, Evidence, Tag, InvestigationTag, InvestigationNote, InvestigationActivity
print("All models imported successfully!")
EOF

# Run system check
python manage.py check
# Should output: System check identified no issues (0 silenced).
```

---

## Why This Fix Works

### Before (Broken Flow):
1. Django runs `pki.0001_initial.py`
2. Migration says "initial=True" so Django expects to **create** tables
3. Migration uses `AddField` which requires table to **already exist**
4. Django looks for `pki_certificate` table
5. Table doesn't exist → `KeyError: ('pki', 'certificate')`

### After (Fixed Flow):
1. Django runs `pki.0001_initial.py`
2. Migration says "initial=True" and **creates** all 3 models
3. `pki_certificate` table created with `certificate_hash` field included
4. Django runs `blockchain.0001_initial.py`
5. Blockchain models reference PKI models (optional FK fields)
6. All tables created successfully

---

## If You Still Get Errors

### Error: "relation already exists"
**Cause**: Old migration state in database
**Fix**:
```bash
# Drop database and migrate from scratch (see Step 2 above)
# OR fake the migrations if you want to keep data:
python manage.py migrate pki --fake-initial
python manage.py migrate blockchain --fake-initial
```

### Error: "cannot import name EncryptTextField"
**Cause**: Missing JumpServer dependency
**Fix**:
```bash
# Check if common.db.fields exists
ls /opt/truefypjs/apps/common/db/fields.py

# If missing, install JumpServer dependencies
pip install -r /opt/truefypjs/requirements/requirements.txt
```

### Error: "no such table: django_migrations"
**Cause**: Database not initialized
**Fix**:
```bash
# Run migrate with --run-syncdb
python manage.py migrate --run-syncdb
```

---

## Summary

✅ **Fixed**: `pki/migrations/0001_initial.py` now properly creates all PKI models
✅ **Ready**: All blockchain UI models (Tag, InvestigationTag, InvestigationNote, InvestigationActivity) already in place
✅ **Verified**: Models.py matches migration exactly
✅ **Action**: Transfer code via SCP, drop database, run migrations from scratch

**Estimated Time**: 5-10 minutes to transfer and migrate

---

**After successful migration**, you can:
1. Start Django server (`python manage.py runserver 0.0.0.0:8080`)
2. Create admin user
3. Access admin panel to create tags, users, certificates
4. Start frontend development using the components in `FRONTEND_COMPONENTS_REMAINING.md`
