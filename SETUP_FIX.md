# Setup Script Fix - manage.py Location

## Issue Resolved

**Problem**: `setup.sh` was looking for `manage.py` in the root directory, but JumpServer has a non-standard structure where `manage.py` is located in `apps/manage.py`.

**Error Message**: `no such file or directory manage.py`

## What Was Fixed

All Django management commands in [setup.sh](setup.sh) have been updated to run from the `apps/` directory:

### Before (Incorrect):
```bash
python manage.py migrate
python manage.py init_pki
python manage.py sync_role
```

### After (Correct):
```bash
cd apps && python manage.py migrate
cd apps && python manage.py init_pki
cd apps && python manage.py sync_role
```

**Total commands fixed**: 13 Django management commands

## Why This Structure?

JumpServer uses a non-standard Django project layout:

```
truefypjs/
├── pyproject.toml          # Root: Dependencies
├── config.yml              # Root: Configuration
├── jms                     # Root: Entry point wrapper
├── apps/
│   ├── manage.py          # ← HERE (not in root!)
│   ├── jumpserver/        # Django project
│   ├── pki/               # PKI app
│   ├── blockchain/        # Blockchain app
│   └── ...
└── data/                   # Data storage
```

The `apps/manage.py` file expects to be run from the `apps/` directory because it creates `../data/logs` (line 7).

## How to Run Setup

### ✅ Correct Way:

```bash
# 1. Navigate to truefypjs root directory
cd /path/to/truefypjs

# 2. Make script executable
chmod +x setup.sh

# 3. Run the script
./setup.sh
```

### ❌ Wrong Ways:

```bash
# DON'T use sudo bash (breaks virtual environment)
sudo bash setup.sh

# DON'T run from apps/ directory (pyproject.toml check will fail)
cd apps && ../setup.sh

# DON'T run from parent directory
cd .. && truefypjs/setup.sh
```

## Important: Ubuntu/Linux Only

**⚠ WARNING**: Your current path shows Windows (`C:\Users\mosta\...`), but `setup.sh` is a **bash script designed for Ubuntu 20.04+**.

You must run this script in one of these environments:

1. **WSL (Windows Subsystem for Linux)**:
   ```bash
   wsl
   cd /mnt/c/Users/mosta/Desktop/FYP/JumpServer/truefypjs
   ./setup.sh
   ```

2. **Ubuntu Virtual Machine** (recommended for production)

3. **Ubuntu Server** (recommended for deployment)

**Why**: The script installs Ubuntu packages with `apt`, configures `nginx`, manages `systemd` services (Redis), and uses bash-specific syntax.

## Verification

After running setup.sh, you can verify it worked:

```bash
# Check manage.py exists
ls -la apps/manage.py

# Test Django from apps directory
cd apps
python manage.py --version

# Check PKI app is registered
cd apps
python manage.py shell -c "from pki.models import CertificateAuthority; print('OK')"
```

## Manual Commands

If you need to run Django commands manually:

```bash
# Always run from apps/ directory
cd truefypjs/apps

# Or use the wrapper from root
cd truefypjs
./jms upgrade_db
```

## Files Updated

1. **[setup.sh](setup.sh)** - All 13 Django commands now use `cd apps &&` prefix
2. **[README.md](README.md)** - Added note about manage.py location
3. **[DEPENDENCIES.md](DEPENDENCIES.md)** - Updated verification commands
4. **This file** - Documentation of the fix

## Next Steps

1. **Run in Ubuntu/WSL**: Transfer to Ubuntu environment if not already there
2. **Run setup.sh**: Execute from truefypjs root directory
3. **Test**: After setup, access at https://localhost (with certificate) or http://localhost:8080 (direct)

---

**Fixed**: 2025-11-04
**Issue**: manage.py location in non-standard Django structure
**Solution**: Updated all commands to use `cd apps && python manage.py ...`
