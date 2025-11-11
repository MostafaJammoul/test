# Fresh Ubuntu Server Installation Guide

This guide provides step-by-step instructions for setting up the JumpServer Blockchain Chain of Custody system on a **fresh Ubuntu server** (Ubuntu 20.04 or newer).

## 📋 Prerequisites

- Fresh Ubuntu Server 20.04+ installation
- Sudo privileges
- At least 5GB free disk space
- Internet connection

## 🚀 Quick Start (One Command)

For a completely fresh Ubuntu installation, you only need to:

```bash
# Clone the repository
git clone <your-repo-url>
cd <repo-directory>

# Make setup script executable
chmod +x setup.sh

# Run the setup script
./setup.sh
```

That's it! The setup script will automatically:
- Install all system dependencies (Python, Node.js, PostgreSQL, Redis, nginx)
- Create databases and users
- Set up virtual environments
- Install Python and npm dependencies
- Run database migrations
- Create superuser account
- Generate certificates (PKI)
- Configure nginx

## 📦 What Gets Installed

The `setup.sh` script automatically installs and configures:

### System Packages
- **Python 3.8+** (upgrades to 3.11 if below 3.8)
  - python3-venv
  - python3-pip
  - python3-dev
- **Node.js 18.x LTS**
  - npm (included)
- **PostgreSQL 12+**
  - postgresql
  - postgresql-contrib
- **Redis 6.x+**
- **nginx**
- **Build tools**
  - build-essential, git, curl, wget
  - Library dependencies (libpq-dev, libssl-dev, etc.)

### Application Setup
- Python virtual environment (`venv/`)
- All Python dependencies from `pyproject.toml`
- All frontend npm dependencies from `frontend/package.json`
- PostgreSQL database (`jumpserver`) with user (`jsroot`)
- Redis server (running)
- Internal PKI/Certificate Authority
- Superuser account with certificate

## 🔍 System Requirements Check

Before installation begins, the script checks:

1. **Sudo privileges** - You must have sudo access
2. **Disk space** - At least 5GB recommended
3. **Port availability** - Checks if required ports are available:
   - 5432 (PostgreSQL)
   - 6379 (Redis)
   - 8080 (Django backend)
   - 3000 (React frontend)
   - 80/443 (nginx)

If any ports are in use, you'll be prompted to continue or cancel.

## ⚙️ Installation Process

The setup script runs through these steps:

### Step 0: Confirmation Prompts
- ⚠️ **WARNING**: The script performs a fresh start and **DELETES ALL EXISTING DATA**
- You must type `yes` and then `DELETE EVERYTHING` to proceed
- This ensures you don't accidentally wipe existing databases

### Step 0.5: System Requirements Check
- Verifies sudo access
- Checks available disk space
- Checks port availability

### Step 1: Environment Cleanup
- Flushes Redis database
- Drops PostgreSQL databases (jumpserver, truefyp_db, etc.)
- Drops PostgreSQL users (jsroot, jumpserver, truefyp_user)
- Drops MySQL databases (if MySQL is installed)
- Deletes old virtual environment (optional, currently disabled)
- Cleans data directories
- Removes Python cache files

### Step 2: Prerequisites
- Installs diagnostic tools (lsof, net-tools)
- Installs Python 3.8+ (or upgrades to 3.11)
- Installs python3-venv and python3-pip
- Verifies Python version meets minimum requirements
- Checks for pyproject.toml file

### Step 3: System Dependencies
- Updates apt package lists
- Installs build tools and libraries
- Installs all required development headers

### Step 3.5: Node.js and npm
- Installs Node.js 18.x LTS from NodeSource repository
- Verifies npm installation
- Upgrades Node.js if version is below 16.x

### Step 4: PostgreSQL Setup
- Installs PostgreSQL server
- Starts and enables PostgreSQL service
- Creates database: `jumpserver`
- Creates user: `jsroot` (password: `jsroot`)
- Grants privileges
- Tests database connection

### Step 5: Redis Setup
- Installs Redis server
- Starts and enables Redis service
- Tests Redis connection (PING/PONG)

### Step 6: Virtual Environment
- Creates Python virtual environment (`venv/`)
- Activates virtual environment

### Step 7: Python Dependencies
- Upgrades pip, setuptools, wheel
- Installs all dependencies from `pyproject.toml`
- This may take 5-10 minutes

### Step 8: Data Directories
Creates directory structure:
```
data/
  ├── logs/          # Application logs
  ├── media/         # User-uploaded media
  ├── static/        # Collected static files
  ├── certs/
  │   ├── pki/       # User certificates (.p12 files)
  │   └── mtls/      # mTLS nginx certificates
  └── uploads/       # Evidence files (mock IPFS)
```

### Step 9: Secret Keys
- Generates random SECRET_KEY (50 chars)
- Generates random BOOTSTRAP_TOKEN (40 chars)
- Saves to `config.yml`

### Step 10: Migrations
- Migrations are already in place from codebase
- PKI fixes are pre-applied

### Step 11: Database Migrations
- Runs `python manage.py migrate`
- Creates all database tables:
  - PKI tables (pki_certificateauthority, pki_certificate, etc.)
  - Blockchain tables (blockchain_investigation, blockchain_evidence, etc.)
  - UI tables (blockchain_tag, blockchain_investigation_note, etc.)

### Step 12: Sync Builtin Roles
- Runs `python manage.py sync_role`
- Creates blockchain roles:
  - SystemAdmin (`00000000-0000-0000-0000-000000000001`)
  - BlockchainInvestigator (`00000000-0000-0000-0000-000000000008`)
  - BlockchainAuditor (`00000000-0000-0000-0000-000000000009`)
  - BlockchainCourt (`00000000-0000-0000-0000-00000000000A`)

### Step 13: Internal Certificate Authority
- Checks if CA already exists
- Creates new CA if needed: `python manage.py create_ca`

### Step 14: nginx Configuration
- Installs nginx
- Generates self-signed SSL certificate for server
- Creates nginx configuration with mTLS support (optional)
- Enables site and reloads nginx

### Step 15: Static Files
- Runs `python manage.py collectstatic --noinput`
- Collects all static files to `data/static/`

### Step 15.5: Frontend Dependencies
- Changes to `frontend/` directory
- Runs `npm install` (may take 5-10 minutes)
- Verifies React and Vite dependencies

### Step 16: Superuser Creation
- Creates superuser automatically:
  - **Username**: `admin` (or `$SUPERUSER_USERNAME`)
  - **Email**: `admin@example.com` (or `$SUPERUSER_EMAIL`)
  - **Password**: `admin` (or `$SUPERUSER_PASSWORD`)
- Sets `is_superuser=True` and `is_staff=True` flags
- Sets `role='Admin'` and `is_active=True`

### Step 17: Superuser Certificate
- Checks if superuser already has certificate
- Generates certificate if needed
- Certificate saved to `data/certs/pki/admin.p12`

### Step 18: Django Configuration Check
- Runs `python manage.py check`
- Verifies no configuration errors

### Step 19: Installation Summary
Displays comprehensive summary showing:
- Installed components and versions
- Database status
- Service status (PostgreSQL, Redis, nginx)
- Application status
- Next steps to start servers

## 🎯 After Installation

### Start the Application

**Option A - Quick Start (Recommended):**
```bash
./start_services.sh
```

**Option B - Manual Start (two terminals):**
```bash
# Terminal 1 - Backend
source venv/bin/activate
cd apps
python manage.py runserver 0.0.0.0:8080

# Terminal 2 - Frontend
cd frontend
npm run dev
```

### Access the Application

- **Frontend**: http://192.168.148.154:3000 (or http://localhost:3000)
- **Django Admin**: http://192.168.148.154:8080/admin
- **API Docs**: http://192.168.148.154:8080/api/docs
- **mTLS Login (nginx)**: https://localhost (requires certificate import)

### Default Credentials

- **Username**: `admin`
- **Password**: `admin`
- ⚠️ **IMPORTANT**: Change this password immediately after first login!

### First Login Workflow

1. Login with password → Redirected to MFA setup
2. Scan QR code with Google Authenticator/Authy
3. Verify 6-digit code → Access dashboard

## 🔧 Customization

You can customize the superuser by setting environment variables before running `setup.sh`:

```bash
export SUPERUSER_USERNAME="myadmin"
export SUPERUSER_EMAIL="admin@mycompany.com"
export SUPERUSER_PASSWORD="MySecurePassword123!"

./setup.sh
```

## 🛠️ Troubleshooting

### Port Conflicts

If you get port conflict warnings:
```bash
# Check what's using a port
sudo lsof -i :8080
sudo netstat -tuln | grep 8080

# Stop the conflicting service
sudo systemctl stop <service-name>
```

### PostgreSQL Connection Issues

```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Restart PostgreSQL
sudo systemctl restart postgresql

# Test connection manually
PGPASSWORD=jsroot psql -h 127.0.0.1 -U jsroot -d jumpserver
```

### Redis Connection Issues

```bash
# Check Redis status
sudo systemctl status redis-server

# Test Redis
redis-cli PING
# Should return: PONG

# Restart Redis
sudo systemctl restart redis-server
```

### Python Virtual Environment Issues

```bash
# Remove and recreate virtual environment
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -e .
```

### Frontend Build Issues

```bash
# Clear npm cache and reinstall
cd frontend
rm -rf node_modules package-lock.json
npm cache clean --force
npm install
```

### Migration Issues

```bash
cd apps
source ../venv/bin/activate

# Check migration status
python manage.py showmigrations

# Run specific app migrations
python manage.py migrate pki
python manage.py migrate blockchain
python manage.py migrate users
```

## 📊 Verification Commands

After installation, verify everything is working:

```bash
# Check Python version
python3 --version

# Check Node.js version
node --version
npm --version

# Check PostgreSQL
PGPASSWORD=jsroot psql -h localhost -U jsroot -d jumpserver -c '\dt'

# Check Redis
redis-cli PING

# Check nginx
sudo nginx -t
sudo systemctl status nginx

# Check virtual environment
source venv/bin/activate
pip list | grep Django

# Check frontend dependencies
cd frontend
npm list react vite
```

## 🔐 Security Notes

1. **Change default password** immediately after first login
2. **Database credentials** are currently set to defaults (`jsroot`/`jsroot`)
   - Consider changing these in production
3. **SECRET_KEY and BOOTSTRAP_TOKEN** are auto-generated
   - Stored in `config.yml`
4. **SSL certificates** are self-signed for testing
   - Use proper CA-signed certificates in production
5. **mTLS is optional** - uncomment nginx configuration to enable

## 📝 Additional Resources

- **Testing Guide**: See `TESTING_GUIDE.md` for testing workflows
- **Role-Based Access**: See `ROLE_BASED_IMPLEMENTATION.md` for role details
- **Start Services Script**: `./start_services.sh`
- **Stop Services Script**: `./stop_services.sh`

## ⚠️ Important Notes

- The setup script is **DESTRUCTIVE** - it wipes all existing databases
- Always run on a fresh Ubuntu installation or be prepared to lose data
- Backup any important data before running
- The script is idempotent - safe to run multiple times (with data loss caveat)

## 🆘 Support

If you encounter issues:

1. Check the logs:
   - Backend: `data/logs/jumpserver.log`
   - nginx: `/var/log/nginx/error.log`
   - PostgreSQL: `/var/log/postgresql/postgresql-*-main.log`

2. Run Django check:
   ```bash
   cd apps
   source ../venv/bin/activate
   python manage.py check
   ```

3. Verify services:
   ```bash
   sudo systemctl status postgresql
   sudo systemctl status redis-server
   sudo systemctl status nginx
   ```

4. Re-run specific setup steps manually if needed

## ✅ Success Checklist

After installation, you should have:

- [ ] Python 3.8+ installed
- [ ] Node.js 18.x installed
- [ ] PostgreSQL running with `jumpserver` database
- [ ] Redis running and responding to PING
- [ ] nginx installed and running
- [ ] Virtual environment created and working
- [ ] Python dependencies installed
- [ ] Frontend dependencies installed (node_modules/)
- [ ] Database migrations applied
- [ ] Superuser account created
- [ ] PKI/CA initialized
- [ ] Services can be started with `./start_services.sh`
- [ ] Can access frontend at http://localhost:3000
- [ ] Can login with admin credentials

---

**Ready to start?** Run `./setup.sh` and follow the prompts!
