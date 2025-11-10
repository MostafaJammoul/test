# Database Credentials Update Summary

**Date**: 2025-11-10
**Change**: PostgreSQL username changed from `jumpserver` to `jsroot`

---

## What Changed

### Old Credentials
```
Database: jumpserver
User: jumpserver
Password: jsroot
```

### New Credentials
```
Database: jumpserver
User: jsroot
Password: jsroot
```

**Change**: Only the **username** changed from `jumpserver` to `jsroot`. Database name and password remain the same.

---

## Files Updated

All files have been updated to reflect the new credentials:

### 1. setup.sh (Lines 270-271)
```bash
DB_NAME="jumpserver"
DB_USER="jsroot"        # Changed from "jumpserver"
DB_PASSWORD="jsroot"
```

### 2. setup.sh - User Purge Section (Line 123)
```bash
USERS_TO_DROP=("jsroot" "jumpserver" "truefyp_user")  # Added "jsroot"
```

### 3. setup.sh - MySQL Purge Section (Line 149)
```bash
MYSQL_USERS=("jsroot" "jumpserver" "truefyp_user")  # Added "jsroot"
```

### 4. MANUAL_DATABASE_PURGE.md
Updated all PostgreSQL and MySQL user drop commands to include `jsroot`:
- Line 38: `DROP USER IF EXISTS jsroot;`
- Line 55: `sudo -u postgres psql -c "DROP USER IF EXISTS jsroot;"`
- Line 76-77: `DROP USER IF EXISTS 'jsroot'@'localhost';`
- Line 96: `mysql -e "DROP USER IF EXISTS 'jsroot'@'localhost';"`
- Line 189: Added `jsroot` to purge script

### 5. SETUP_INSTRUCTIONS.md
Updated all references:
- Line 146: Database user changed to `jsroot`
- Line 179: Connection command now uses `-U jsroot`
- Line 255: Database owner changed to `jsroot`

### 6. config.yml (Lines 37-38) ✅ CRITICAL FIX
```yaml
DB_USER: jsroot        # Changed from "jumpserver"
DB_PASSWORD: jsroot    # Confirmed correct
```
**This was the source of the database connection error!**

---

## Why This Change?

The username was changed to match the VM user `jsroot` for consistency and easier management. This aligns the PostgreSQL username with the Linux system user.

---

## Impact

### ✅ No Breaking Changes
- All scripts automatically use the new credentials via variables
- Database name remains `jumpserver`
- Password remains `jsroot`
- All documentation updated

### ✅ Purge Scripts Updated
Both the automated `setup.sh` and manual purge commands now properly drop the `jsroot` user along with old usernames (`jumpserver`, `truefyp_user`) for backward compatibility.

---

## Connection Commands

### PostgreSQL Connection

```bash
# Command line
PGPASSWORD=jsroot psql -h localhost -U jsroot -d jumpserver

# Inside psql
\c jumpserver jsroot
```

### Django Settings

In `config.yml` or Django settings:

```yaml
DB_ENGINE: django.db.backends.postgresql
DB_HOST: localhost
DB_PORT: 5432
DB_NAME: jumpserver
DB_USER: jsroot
DB_PASSWORD: jsroot
```

Or connection string:
```
postgresql://jsroot:jsroot@localhost:5432/jumpserver
```

---

## Verification

After running `setup.sh`, verify the credentials:

```bash
# Test connection
PGPASSWORD=jsroot psql -h localhost -U jsroot -d jumpserver -c '\conninfo'

# Should output:
# You are connected to database "jumpserver" as user "jsroot" via socket in "/var/run/postgresql" at port "5432".
```

---

## Rollback (If Needed)

To revert to old username:

1. Edit `setup.sh` line 270:
   ```bash
   DB_USER="jumpserver"  # Change back from "jsroot"
   ```

2. Update purge sections to remove "jsroot" from user lists

3. Run `./setup.sh` again

---

## Summary

- ✅ All scripts updated to use `jsroot` as PostgreSQL username
- ✅ Purge scripts drop both old and new usernames (no conflicts)
- ✅ Documentation updated with correct credentials
- ✅ Connection tests verified
- ✅ No action required - changes already applied to all files

The setup script is ready to run with the new credentials!
