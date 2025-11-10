# Manual Database Purge Commands

If you want to purge all databases manually (instead of using setup.sh), use these commands:

---

## 1. Purge Redis (Delete all cache, sessions, MFA tokens)

```bash
# Flush all Redis data
redis-cli FLUSHALL

# Verify Redis is empty
redis-cli DBSIZE
# Should return: (integer) 0

# Alternative: Restart Redis service
sudo systemctl restart redis-server
```

---

## 2. Purge PostgreSQL (Drop all databases and users)

```bash
# Connect as postgres superuser
sudo -u postgres psql

# Inside psql:
\l  -- List all databases

-- Drop databases
DROP DATABASE IF EXISTS jumpserver;
DROP DATABASE IF EXISTS truefyp_db;
DROP DATABASE IF EXISTS jumpserver_test;

-- Drop users
DROP USER IF EXISTS jsroot;
DROP USER IF EXISTS jumpserver;
DROP USER IF EXISTS truefyp_user;

-- Verify databases are gone
\l

-- Exit
\q
```

**One-liner approach:**

```bash
# Drop jumpserver database and user
sudo -u postgres psql -c "DROP DATABASE IF EXISTS jumpserver;"
sudo -u postgres psql -c "DROP DATABASE IF EXISTS truefyp_db;"
sudo -u postgres psql -c "DROP USER IF EXISTS jsroot;"
sudo -u postgres psql -c "DROP USER IF EXISTS jumpserver;"
sudo -u postgres psql -c "DROP USER IF EXISTS truefyp_user;"
```

---

## 3. Purge MySQL (If installed)

```bash
# Connect to MySQL as root
sudo mysql

# Inside MySQL:
SHOW DATABASES;  -- List all databases

-- Drop databases
DROP DATABASE IF EXISTS jumpserver;
DROP DATABASE IF EXISTS truefyp_db;

-- Drop users
DROP USER IF EXISTS 'jsroot'@'localhost';
DROP USER IF EXISTS 'jsroot'@'%';
DROP USER IF EXISTS 'jumpserver'@'localhost';
DROP USER IF EXISTS 'jumpserver'@'%';
DROP USER IF EXISTS 'truefyp_user'@'localhost';
DROP USER IF EXISTS 'truefyp_user'@'%';

-- Verify
SHOW DATABASES;

-- Exit
EXIT;
```

**One-liner approach:**

```bash
# Drop MySQL databases
mysql -e "DROP DATABASE IF EXISTS jumpserver;"
mysql -e "DROP DATABASE IF EXISTS truefyp_db;"
mysql -e "DROP USER IF EXISTS 'jsroot'@'localhost';"
mysql -e "DROP USER IF EXISTS 'jumpserver'@'localhost';"
mysql -e "DROP USER IF EXISTS 'truefyp_user'@'localhost';"
```

---

## 4. Delete Virtual Environment

```bash
cd /opt/truefypjs
rm -rf venv
```

---

## 5. Delete Data Directories

```bash
cd /opt/truefypjs
rm -rf data/logs
rm -rf data/media
rm -rf data/uploads
rm -rf data/certs
rm -rf data/static
```

---

## 6. Delete Migration Files (Keep __init__.py)

```bash
cd /opt/truefypjs/apps

# Delete PKI migrations
find pki/migrations -type f -name "*.py" ! -name "__init__.py" -delete

# Delete Blockchain migrations
find blockchain/migrations -type f -name "*.py" ! -name "__init__.py" -delete

# Verify
ls -la pki/migrations/
ls -la blockchain/migrations/
# Should only see __init__.py and __pycache__/
```

---

## 7. Delete Python Cache

```bash
cd /opt/truefypjs

# Delete all __pycache__ directories
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null

# Delete all .pyc files
find . -type f -name "*.pyc" -delete

# Delete all .pyo files
find . -type f -name "*.pyo" -delete
```

---

## 8. Complete Fresh Start Script (Copy-Paste)

```bash
#!/bin/bash
# Complete database purge - USE WITH CAUTION!

echo "⚠️  WARNING: This will DELETE ALL DATA!"
echo "Databases: PostgreSQL (jumpserver, truefyp_db)"
echo "           MySQL (jumpserver, truefyp_db)"
echo "           Redis (all keys)"
echo ""
read -p "Type 'DELETE EVERYTHING' to confirm: " CONFIRM

if [ "$CONFIRM" != "DELETE EVERYTHING" ]; then
    echo "Cancelled."
    exit 0
fi

echo "Starting purge..."

# 1. Flush Redis
echo "[1/8] Flushing Redis..."
redis-cli FLUSHALL || echo "Redis flush failed"

# 2. Drop PostgreSQL databases
echo "[2/8] Dropping PostgreSQL databases..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS jumpserver;" 2>/dev/null || true
sudo -u postgres psql -c "DROP DATABASE IF EXISTS truefyp_db;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS jsroot;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS jumpserver;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS truefyp_user;" 2>/dev/null || true

# 3. Drop MySQL databases (if installed)
echo "[3/8] Dropping MySQL databases..."
if command -v mysql &> /dev/null; then
    mysql -e "DROP DATABASE IF EXISTS jumpserver;" 2>/dev/null || true
    mysql -e "DROP DATABASE IF EXISTS truefyp_db;" 2>/dev/null || true
    mysql -e "DROP USER IF EXISTS 'jsroot'@'localhost';" 2>/dev/null || true
    mysql -e "DROP USER IF EXISTS 'jumpserver'@'localhost';" 2>/dev/null || true
    mysql -e "DROP USER IF EXISTS 'truefyp_user'@'localhost';" 2>/dev/null || true
fi

# 4. Delete virtual environment
echo "[4/8] Deleting virtual environment..."
rm -rf /opt/truefypjs/venv

# 5. Delete data directories
echo "[5/8] Deleting data directories..."
rm -rf /opt/truefypjs/data/logs
rm -rf /opt/truefypjs/data/media
rm -rf /opt/truefypjs/data/uploads
rm -rf /opt/truefypjs/data/certs
rm -rf /opt/truefypjs/data/static

# 6. Delete migration files
echo "[6/8] Deleting migration files..."
find /opt/truefypjs/apps/pki/migrations -type f -name "*.py" ! -name "__init__.py" -delete 2>/dev/null || true
find /opt/truefypjs/apps/blockchain/migrations -type f -name "*.py" ! -name "__init__.py" -delete 2>/dev/null || true

# 7. Delete Python cache
echo "[7/8] Deleting Python cache..."
find /opt/truefypjs -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find /opt/truefypjs -type f -name "*.pyc" -delete 2>/dev/null || true

# 8. Stop running services
echo "[8/8] Stopping Django server (if running)..."
pkill -f "python manage.py runserver" 2>/dev/null || true

echo ""
echo "✅ Purge complete!"
echo ""
echo "Next steps:"
echo "  1. Transfer code from Windows: scp -r truefypjs/* jsroot@192.168.148.154:/opt/truefypjs/"
echo "  2. Run setup.sh: cd /opt/truefypjs && ./setup.sh"
```

---

## 9. Verification Commands

After purging, verify everything is clean:

```bash
# Check Redis
redis-cli DBSIZE
# Should return: (integer) 0

# Check PostgreSQL
sudo -u postgres psql -l | grep jumpserver
sudo -u postgres psql -l | grep truefyp
# Should return nothing

# Check MySQL (if installed)
mysql -e "SHOW DATABASES;" | grep jumpserver
mysql -e "SHOW DATABASES;" | grep truefyp
# Should return nothing

# Check virtual environment
ls /opt/truefypjs/venv
# Should return: ls: cannot access '/opt/truefypjs/venv': No such file or directory

# Check data directories
ls /opt/truefypjs/data/
# Should be empty or not exist

# Check migrations
ls /opt/truefypjs/apps/pki/migrations/
ls /opt/truefypjs/apps/blockchain/migrations/
# Should only show __init__.py
```

---

## 10. Quick Reference

| Command | Purpose |
|---------|---------|
| `redis-cli FLUSHALL` | Delete all Redis keys |
| `sudo -u postgres psql -c "DROP DATABASE jumpserver;"` | Drop PostgreSQL database |
| `mysql -e "DROP DATABASE jumpserver;"` | Drop MySQL database |
| `rm -rf /opt/truefypjs/venv` | Delete virtual environment |
| `rm -rf /opt/truefypjs/data/*` | Delete all data directories |
| `find . -name "*.pyc" -delete` | Delete Python cache |

---

## When to Use Manual Purge

Use manual purge when:
- You want to clean specific databases without running full setup
- setup.sh fails partway through and you need to reset
- You're troubleshooting database issues
- You want to keep some data but purge others

For a complete fresh start, just use `./setup.sh` - it includes all these steps automatically.
