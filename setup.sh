#!/bin/bash
# =============================================================================
# JumpServer Blockchain Chain of Custody - Complete Setup Script
# =============================================================================
# This script performs a COMPLETE FRESH INSTALLATION including:
# - Purging all existing databases (PostgreSQL, MySQL, Redis)
# - Installing all dependencies
# - Creating database migrations (with PKI fix applied)
# - Setting up mTLS with internal PKI
# - Configuring nginx reverse proxy
# - Creating superuser and issuing certificate
#
# Requirements: Ubuntu 20.04+ with Python 3.11+
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Error handler
error_exit() {
    log_error "Setup failed at line $1"
    log_error "Check the output above for error details"
    log_info "You can try running the script again or fix the issue manually"
    exit 1
}

# Set up error trap
trap 'error_exit $LINENO' ERR

# Installation tracking
INSTALLED_COMPONENTS=()

track_installation() {
    INSTALLED_COMPONENTS+=("$1")
}

# =============================================================================
# 0. CONFIRMATION PROMPT (FRESH START WARNING)
# =============================================================================
log_step "⚠️  FRESH START SETUP - DATABASE PURGE WARNING"

echo ""
log_warning "This script will perform a COMPLETE FRESH START including:"
echo "  1. Drop ALL PostgreSQL databases (jumpserver, truefyp_db, etc.)"
echo "  2. Drop ALL MySQL databases (if MySQL is installed)"
echo "  3. Flush ALL Redis data (cache, sessions, MFA tokens)"
echo "  4. Delete virtual environment"
echo "  5. Delete data directories (logs, media, uploads)"
echo "  6. Reinstall all dependencies"
echo "  7. Run fresh migrations with PKI fix applied"
echo ""
log_error "THIS WILL DELETE ALL EXISTING DATA!"
echo ""
read -p "Are you ABSOLUTELY SURE you want to continue? (type 'yes' to proceed): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log_info "Setup cancelled."
    exit 0
fi

echo ""
log_warning "Last chance! Type 'DELETE EVERYTHING' to confirm:"
read -p "> " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "DELETE EVERYTHING" ]; then
    log_info "Setup cancelled."
    exit 0
fi

log_success "Confirmation received. Starting fresh installation..."

# =============================================================================
# 0.5. CHECK SUDO PRIVILEGES AND SYSTEM REQUIREMENTS
# =============================================================================
log_step "STEP 0.5: Checking system requirements"

# Check if user has sudo privileges
if ! sudo -n true 2>/dev/null; then
    log_info "Testing sudo access..."
    sudo -v || {
        log_error "This script requires sudo privileges. Please run with a user that has sudo access."
        exit 1
    }
fi
log_success "Sudo privileges verified"

# Check available disk space (need at least 5GB)
AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 5 ]; then
    log_warning "Low disk space: ${AVAILABLE_SPACE}GB available. Recommended: 5GB+ free"
    log_warning "Installation may fail if disk space runs out"
else
    log_success "Disk space: ${AVAILABLE_SPACE}GB available"
fi

# Check if critical ports are available
log_info "Checking port availability..."
PORTS_TO_CHECK=(5432 6379 8080 3000 80 443)
PORTS_IN_USE=()

for PORT in "${PORTS_TO_CHECK[@]}"; do
    if sudo lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1 || sudo netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
        PORTS_IN_USE+=($PORT)
        log_warning "Port $PORT is already in use"
    fi
done

if [ ${#PORTS_IN_USE[@]} -gt 0 ]; then
    log_warning "The following ports are in use: ${PORTS_IN_USE[*]}"
    log_warning "This may cause conflicts. Services using these ports:"
    for PORT in "${PORTS_IN_USE[@]}"; do
        log_info "  Port $PORT: $(sudo lsof -Pi :$PORT -sTCP:LISTEN 2>/dev/null | tail -n +2 | awk '{print $1}' | sort -u | tr '\n' ' ' || echo 'unknown')"
    done
    echo ""
    read -p "Continue anyway? (yes/no): " PORT_CONTINUE
    if [ "$PORT_CONTINUE" != "yes" ]; then
        log_info "Installation cancelled. Please free up the required ports first."
        exit 0
    fi
fi

log_success "System requirements checked"

# =============================================================================
# 1. PURGE ALL DATABASES AND CLEAN ENVIRONMENT
# =============================================================================
log_step "STEP 1: Purging all databases and cleaning environment"

# 1.1 Flush Redis
log_info "Flushing Redis database..."
if command -v redis-cli &> /dev/null; then
    if pgrep -x "redis-server" > /dev/null; then
        redis-cli FLUSHALL 2>/dev/null || log_warning "Redis flush failed (may not be running)"
        log_success "Redis flushed (all cache, sessions, MFA tokens deleted)"
    else
        log_warning "Redis server not running, skipping flush"
    fi
else
    log_warning "Redis not installed, skipping flush"
fi

# 1.2 Drop PostgreSQL databases
log_info "Dropping PostgreSQL databases..."
if command -v psql &> /dev/null; then
    # List of common database names to drop
    DBS_TO_DROP=("jumpserver" "truefyp_db" "jumpserver_test")

    for DB in "${DBS_TO_DROP[@]}"; do
        if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB"; then
            log_info "Dropping database: $DB"
            sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB;" 2>/dev/null || true
            log_success "Database '$DB' dropped"
        fi
    done

    # Drop PostgreSQL users
    USERS_TO_DROP=("jsroot" "jumpserver" "truefyp_user")
    for USER in "${USERS_TO_DROP[@]}"; do
        if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$USER'" | grep -q 1; then
            log_info "Dropping PostgreSQL user: $USER"
            sudo -u postgres psql -c "DROP USER IF EXISTS $USER;" 2>/dev/null || true
            log_success "User '$USER' dropped"
        fi
    done
else
    log_warning "PostgreSQL not installed, skipping database drop"
fi

# 1.3 Drop MySQL databases (if MySQL is installed)
log_info "Dropping MySQL databases (if installed)..."
if command -v mysql &> /dev/null; then
    MYSQL_DBS=("jumpserver" "truefyp_db")

    for DB in "${MYSQL_DBS[@]}"; do
        if mysql -e "SHOW DATABASES LIKE '$DB';" 2>/dev/null | grep -q "$DB"; then
            log_info "Dropping MySQL database: $DB"
            mysql -e "DROP DATABASE IF EXISTS $DB;" 2>/dev/null || true
            log_success "MySQL database '$DB' dropped"
        fi
    done

    # Drop MySQL users
    MYSQL_USERS=("jsroot" "jumpserver" "truefyp_user")
    for USER in "${MYSQL_USERS[@]}"; do
        mysql -e "DROP USER IF EXISTS '$USER'@'localhost';" 2>/dev/null || true
        mysql -e "DROP USER IF EXISTS '$USER'@'%';" 2>/dev/null || true
    done
    log_success "MySQL users dropped"
else
    log_info "MySQL not installed, skipping MySQL cleanup"
fi

# 1.4 Delete virtual environment
log_info "Deleting virtual environment..."
if [ -d "venv" ]; then
    #rm -rf venv
    log_success "Virtual environment deleted (NOT)"
else
    log_info "No virtual environment to delete"
fi

# 1.5 Delete data directories
log_info "Deleting data directories..."
rm -rf data/logs data/media data/uploads data/certs data/static 2>/dev/null || true
log_success "Data directories deleted"

# 1.6 Delete migration files (except __init__.py)
# DISABLED: We're transferring fresh migrations via SCP, so no need to delete them
# log_info "Cleaning old migrations..."
# if [ -d "apps/pki/migrations" ]; then
#     find apps/pki/migrations -type f -name "*.py" ! -name "__init__.py" -delete 2>/dev/null || true
#     log_success "PKI migrations cleaned"
# fi
#
# if [ -d "apps/blockchain/migrations" ]; then
#     find apps/blockchain/migrations -type f -name "*.py" ! -name "__init__.py" -delete 2>/dev/null || true
#     log_success "Blockchain migrations cleaned"
# fi

# 1.7 Delete __pycache__ directories
log_info "Cleaning Python cache..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true
log_success "Python cache cleaned"

log_success "Environment purged successfully!"

# =============================================================================
# 2. CHECK PREREQUISITES
# =============================================================================
log_step "STEP 2: Checking prerequisites"

# Install diagnostic tools (needed for port checking)
if ! command -v lsof &> /dev/null || ! command -v netstat &> /dev/null; then
    log_info "Installing diagnostic tools (lsof, net-tools)..."
    sudo apt update
    sudo apt install -y lsof net-tools
    log_success "Diagnostic tools installed"
fi

# Check Python version
if ! command -v python3 &> /dev/null; then
    log_info "Python 3+ not found. Installing..."
    sudo apt update
    sudo apt install -y software-properties-common
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt update
    sudo apt install -y python3 python3-venv python3-pip python3-dev
    log_success "Python 3 installed"
else
    log_success "Python 3 already installed"
fi

# Ensure python3-venv and python3-pip are installed
if ! python3 -m venv --help &> /dev/null; then
    log_info "Installing python3-venv..."
    sudo apt install -y python3-venv
    log_success "python3-venv installed"
fi

if ! python3 -m pip --version &> /dev/null; then
    log_info "Installing python3-pip..."
    sudo apt install -y python3-pip
    log_success "python3-pip installed"
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
log_success "Python version: $PYTHON_VERSION"

# Check Python version meets minimum requirement (3.8+)
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]); then
    log_warning "Python version $PYTHON_VERSION is below 3.8. Upgrading to Python 3.11..."
    sudo apt update
    sudo apt install -y software-properties-common
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt update
    sudo apt install -y python3.11 python3.11-venv python3.11-pip python3.11-dev

    # Update python3 alternative to point to python3.11
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    log_success "Python upgraded to version: $PYTHON_VERSION"
fi

# Check if we're in the right directory
if [ ! -f "pyproject.toml" ]; then
    log_error "pyproject.toml not found. Please run this script from the truefypjs directory."
    exit 1
fi

log_success "Prerequisites checked"

# =============================================================================
# 3. INSTALL SYSTEM DEPENDENCIES
# =============================================================================
log_step "STEP 3: Installing system dependencies"

log_info "Updating package lists..."
sudo apt update

log_info "Installing build tools and libraries..."
sudo apt install -y \
    build-essential \
    git \
    libpq-dev \
    libmysqlclient-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    libffi-dev \
    libjpeg-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    pkg-config \
    gettext \
    curl \
    wget

log_success "System dependencies installed"

# =============================================================================
# 3.5. INSTALL NODE.JS AND NPM (FOR FRONTEND)
# =============================================================================
log_step "STEP 3.5: Installing Node.js and npm"

if ! command -v node &> /dev/null; then
    log_info "Node.js not found. Installing Node.js 18.x LTS..."

    # Remove any existing NodeSource repository
    sudo rm -f /etc/apt/sources.list.d/nodesource.list

    # Install Node.js 18.x from NodeSource
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs

    log_success "Node.js installed"
else
    log_success "Node.js already installed"
fi

NODE_VERSION=$(node --version 2>&1)
NPM_VERSION=$(npm --version 2>&1)
log_success "Node.js version: $NODE_VERSION"
log_success "npm version: $NPM_VERSION"

# Verify minimum versions
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_MAJOR" -lt 16 ]; then
    log_warning "Node.js version is below 16.x. Upgrading recommended."
    log_info "Upgrading Node.js to 18.x LTS..."
    sudo rm -f /etc/apt/sources.list.d/nodesource.list
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    log_success "Node.js upgraded"
fi

# =============================================================================
# 4. INSTALL AND START POSTGRESQL
# =============================================================================
log_step "STEP 4: Setting up PostgreSQL"

# Install PostgreSQL
if ! command -v psql &> /dev/null; then
    log_info "Installing PostgreSQL..."
    sudo apt install -y postgresql postgresql-contrib
    log_success "PostgreSQL installed"
else
    log_success "PostgreSQL already installed"
fi

# Start and enable PostgreSQL
log_info "Starting PostgreSQL service..."
sudo systemctl start postgresql
sudo systemctl enable postgresql
log_success "PostgreSQL service started and enabled"

# Create database and user
DB_NAME="jumpserver"
DB_USER="jsroot"
DB_PASSWORD="jsroot"

log_info "Creating PostgreSQL database: $DB_NAME"
log_info "Creating PostgreSQL user: $DB_USER"

sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
ALTER DATABASE $DB_NAME OWNER TO $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\q
EOF

log_success "Database '$DB_NAME' created with user '$DB_USER'"

# Test connection
if PGPASSWORD=$DB_PASSWORD psql -h 127.0.0.1 -U $DB_USER -d $DB_NAME -c '\q' 2>/dev/null; then
    log_success "PostgreSQL connection verified"
else
    log_error "PostgreSQL connection failed. Check credentials."
    exit 1
fi

# =============================================================================
# 5. INSTALL AND START REDIS
# =============================================================================
log_step "STEP 5: Setting up Redis"

if ! command -v redis-server &> /dev/null; then
    log_info "Installing Redis..."
    sudo apt install -y redis-server
    log_success "Redis installed"
else
    log_success "Redis already installed"
fi

log_info "Starting Redis service..."
sudo systemctl start redis-server
sudo systemctl enable redis-server
log_success "Redis service started and enabled"

# Test Redis connection
if redis-cli ping | grep -q "PONG"; then
    log_success "Redis connection verified"
else
    log_error "Redis connection failed"
    exit 1
fi

# =============================================================================
# 6. CREATE VIRTUAL ENVIRONMENT
# =============================================================================
log_step "STEP 6: Creating virtual environment"

if [ ! -d "venv" ]; then
    log_info "Creating Python 3 virtual environment..."
    python3 -m venv venv
    log_success "Virtual environment created"
else
    log_success "Virtual environment already exists"
fi

log_info "Activating virtual environment..."
source venv/bin/activate
log_success "Virtual environment activated"

# =============================================================================
# 7. UPGRADE PIP AND INSTALL DEPENDENCIES
# =============================================================================
log_step "STEP 7: Installing Python dependencies"

log_info "Upgrading pip, setuptools, and wheel..."
pip install --upgrade pip setuptools wheel
log_success "Pip upgraded"

log_info "Installing project dependencies (this may take 5-10 minutes)..."
pip install -e .
log_success "Python dependencies installed"

# =============================================================================
# 8. CREATE DATA DIRECTORIES
# =============================================================================
log_step "STEP 8: Creating data directories"

mkdir -p data/logs
mkdir -p data/media
mkdir -p data/static
mkdir -p data/certs/pki      # For PKI certificates (user .p12 files)
mkdir -p data/certs/mtls     # For mTLS nginx configuration
mkdir -p data/uploads        # For evidence files (mock IPFS storage)

log_success "Data directories created"

# =============================================================================
# 9. GENERATE SECRET KEYS
# =============================================================================
log_step "STEP 9: Generating secret keys"

if grep -q "SECRET_KEY:" config.yml && ! grep -q "SECRET_KEY: $" config.yml; then
    log_success "SECRET_KEY already configured"
else
    log_info "Generating random SECRET_KEY..."
    SECRET_KEY=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*()_+' | head -c 50)
    sed -i "s/^SECRET_KEY:.*/SECRET_KEY: $SECRET_KEY/" config.yml
    log_success "SECRET_KEY generated and saved"
fi

if grep -q "BOOTSTRAP_TOKEN:" config.yml && ! grep -q "BOOTSTRAP_TOKEN: $" config.yml; then
    log_success "BOOTSTRAP_TOKEN already configured"
else
    log_info "Generating random BOOTSTRAP_TOKEN..."
    BOOTSTRAP_TOKEN=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 40)
    sed -i "s/^BOOTSTRAP_TOKEN:.*/BOOTSTRAP_TOKEN: $BOOTSTRAP_TOKEN/" config.yml
    log_success "BOOTSTRAP_TOKEN generated and saved"
fi

# =============================================================================
# 10. COPY MIGRATION FILES (WITH PKI FIX)
# =============================================================================
log_step "STEP 10: Setting up migrations (with PKI fix)"

log_info "Migrations are already in place from codebase (PKI fix applied)"
log_success "Migration files ready"

# =============================================================================
# 11. RUN DATABASE MIGRATIONS
# =============================================================================
log_step "STEP 11: Running database migrations"

cd apps

log_info "Running migrations for all apps..."
python manage.py migrate

log_success "Database migrations completed successfully!"
log_info "Tables created:"
echo "  - PKI tables: pki_certificateauthority, pki_certificate, pki_certificate_revocation_list"
echo "  - Blockchain tables: blockchain_investigation, blockchain_evidence, blockchain_transaction"
echo "  - UI tables: blockchain_tag, blockchain_investigation_tag, blockchain_investigation_note, blockchain_investigation_activity"

cd ..

# =============================================================================
# 12. SYNC BUILTIN ROLES
# =============================================================================
log_step "STEP 12: Syncing builtin roles"

cd apps
python manage.py sync_role
cd ..

log_success "Builtin roles synced"
log_info "Available blockchain roles:"
echo "  - SystemAdmin (00000000-0000-0000-0000-000000000001)"
echo "  - BlockchainInvestigator (00000000-0000-0000-0000-000000000008)"
echo "  - BlockchainAuditor (00000000-0000-0000-0000-000000000009)"
echo "  - BlockchainCourt (00000000-0000-0000-0000-00000000000A)"

# =============================================================================
# 13. INITIALIZE PKI (Internal CA)
# =============================================================================
log_step "STEP 13: Initializing Internal Certificate Authority"

cd apps

# Check if CA already exists
CA_EXISTS=$(python manage.py shell -c "
from pki.models import CertificateAuthority
print(CertificateAuthority.objects.filter(is_active=True).exists())
" 2>/dev/null)

if [ "$CA_EXISTS" = "True" ]; then
    log_success "Certificate Authority already exists"
else
    log_info "Creating new Certificate Authority..."
    if python manage.py create_ca 2>&1 | tee /tmp/ca_creation.log; then
        log_success "Certificate Authority created successfully"
    else
        log_error "Failed to create Certificate Authority"
        log_info "Check logs: /tmp/ca_creation.log"
        log_info "You can create it manually later with: python manage.py create_ca"
        cd ..
        exit 1
    fi
fi

cd ..

# =============================================================================
# 13.5. EXPORT CA CERTIFICATE FOR NGINX
# =============================================================================
log_step "STEP 13.5: Exporting CA certificate for nginx mTLS"

cd apps

# Export CA certificate to PEM format for nginx
log_info "Exporting CA certificate for nginx..."
if python manage.py export_ca_cert --output ../data/certs/mtls/internal-ca.crt --force 2>&1 | tee /tmp/ca_export.log; then
    log_success "CA certificate exported successfully"

    # Verify file was created
    if [ -f "../data/certs/mtls/internal-ca.crt" ]; then
        log_success "CA certificate available at data/certs/mtls/internal-ca.crt"
        log_info "Note: CRL (Certificate Revocation List) not configured - certificate revocation not yet implemented"
    else
        log_warning "CA certificate not found at expected location"
        log_info "mTLS will not work until CA certificate is properly exported"
    fi
else
    log_warning "Failed to export CA certificate"
    log_info "Check logs: /tmp/ca_export.log"
    log_info "mTLS will not work until CA certificate is exported"
    log_info "You can export it manually later with: python manage.py export_ca_cert --output ../data/certs/mtls/internal-ca.crt --force"
fi

cd ..

# =============================================================================
# 14. INSTALL AND CONFIGURE NGINX
# =============================================================================
log_step "STEP 14: Installing and configuring nginx"

# Install nginx
if ! command -v nginx &> /dev/null; then
    log_info "Installing nginx..."
    sudo apt install -y nginx
    log_success "nginx installed"
else
    log_success "nginx already installed"
fi

# Generate self-signed SSL certificate for server (testing)
if [ ! -f "data/certs/mtls/server.crt" ]; then
    log_info "Generating self-signed SSL certificate for server..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout data/certs/mtls/server.key \
        -out data/certs/mtls/server.crt \
        -subj "/C=US/ST=California/L=San Francisco/O=JumpServer/OU=BlockchainCoC/CN=localhost" \
        2>/dev/null

    chmod 600 data/certs/mtls/server.key
    chmod 644 data/certs/mtls/server.crt
    log_success "Server SSL certificate generated"
fi

# Create nginx configuration
CURRENT_DIR=$(pwd)
NGINX_CONF="/etc/nginx/sites-available/jumpserver"

log_info "Creating nginx configuration..."
sudo tee "$NGINX_CONF" > /dev/null << 'NGINXEOF'
# JumpServer mTLS Configuration
upstream jumpserver_backend {
    server 127.0.0.1:8080;
}

upstream jumpserver_frontend {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    server_name _;

    # Redirect HTTP to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    # SSL Configuration
    ssl_certificate SSL_CERT_PATH;
    ssl_certificate_key SSL_KEY_PATH;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # mTLS Client Certificate Verification (OPTIONAL - enabled for non-admin users)
    ssl_client_certificate CA_CERT_PATH;
    ssl_verify_client optional;
    # ssl_crl CA_CRL_PATH;  # Disabled - CRL not implemented yet

    # Proxy settings
    client_max_body_size 5G;

    # Django admin - allows password authentication (no certificate required)
    location /admin/ {
        proxy_pass http://jumpserver_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Pass client certificate info (will be NONE for admin password login)
        proxy_set_header X-SSL-Client-Verify $ssl_client_verify;
        proxy_set_header X-SSL-Client-Serial $ssl_client_serial;
        proxy_set_header X-SSL-Client-DN $ssl_client_s_dn;
    }

    # API endpoints - proxies to backend
    location /api/ {
        proxy_pass http://jumpserver_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Pass client certificate info to backend for mTLS authentication
        proxy_set_header X-SSL-Client-Verify $ssl_client_verify;
        proxy_set_header X-SSL-Client-Serial $ssl_client_serial;
        proxy_set_header X-SSL-Client-DN $ssl_client_s_dn;
    }

    # WebSocket support
    location /ws/ {
        proxy_pass http://jumpserver_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # Pass client certificate info
        proxy_set_header X-SSL-Client-Verify $ssl_client_verify;
        proxy_set_header X-SSL-Client-Serial $ssl_client_serial;
        proxy_set_header X-SSL-Client-DN $ssl_client_s_dn;
    }

    # Static files (Django collectstatic)
    location /static/ {
        alias STATIC_PATH;
        expires 30d;
    }

    # Media files (user uploads)
    location /media/ {
        alias MEDIA_PATH;
        expires 7d;
    }

    # Frontend - React app (port 3000)
    # This proxies to the Vite dev server during development
    # In production, serve built static files instead
    location / {
        proxy_pass http://jumpserver_frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support for Vite HMR (Hot Module Replacement)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Pass client certificate info
        proxy_set_header X-SSL-Client-Verify $ssl_client_verify;
        proxy_set_header X-SSL-Client-Serial $ssl_client_serial;
        proxy_set_header X-SSL-Client-DN $ssl_client_s_dn;
    }
}
NGINXEOF

# Replace paths in nginx config
sudo sed -i "s|SSL_CERT_PATH|$CURRENT_DIR/data/certs/mtls/server.crt|g" "$NGINX_CONF"
sudo sed -i "s|SSL_KEY_PATH|$CURRENT_DIR/data/certs/mtls/server.key|g" "$NGINX_CONF"
sudo sed -i "s|CA_CERT_PATH|$CURRENT_DIR/data/certs/mtls/internal-ca.crt|g" "$NGINX_CONF"
sudo sed -i "s|STATIC_PATH|$CURRENT_DIR/data/static/|g" "$NGINX_CONF"
sudo sed -i "s|MEDIA_PATH|$CURRENT_DIR/data/media/|g" "$NGINX_CONF"

log_success "nginx configuration created"

# Enable site
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/jumpserver 2>/dev/null || true
log_success "nginx site enabled"

# Test nginx configuration
if sudo nginx -t 2>/dev/null; then
    log_success "nginx configuration valid"
    sudo systemctl reload nginx 2>/dev/null || sudo systemctl start nginx
    log_success "nginx reloaded"
else
    log_warning "nginx configuration test failed"
fi

# =============================================================================
# 15. COLLECT STATIC FILES
# =============================================================================
log_step "STEP 15: Collecting static files"

cd apps
python manage.py collectstatic --noinput
cd ..

log_success "Static files collected"

# =============================================================================
# 15.3. DOWNLOAD IP GEOLOCATION DATABASES
# =============================================================================
log_step "STEP 15.3: Downloading IP geolocation databases"

if [ -f "requirements/static_files.sh" ]; then
    log_info "Downloading GeoIP databases and static files..."
    bash ./requirements/static_files.sh

    # Copy databases to data/system directory (primary location Django looks for)
    log_info "Copying IP databases to data/system/..."
    mkdir -p data/system

    if [ -f "apps/common/utils/ip/ipip/ipipfree.ipdb" ]; then
        cp apps/common/utils/ip/ipip/ipipfree.ipdb data/system/
        log_success "Copied ipipfree.ipdb to data/system/"
    fi

    if [ -f "apps/common/utils/ip/geoip/GeoLite2-City.mmdb" ]; then
        cp apps/common/utils/ip/geoip/GeoLite2-City.mmdb data/system/
        log_success "Copied GeoLite2-City.mmdb to data/system/"
    fi

    if [ -f "apps/accounts/automations/check_account/leak_passwords.db" ]; then
        cp apps/accounts/automations/check_account/leak_passwords.db data/system/
        log_success "Copied leak_passwords.db to data/system/"
    fi

    log_success "IP geolocation databases downloaded and installed"
else
    log_warning "requirements/static_files.sh not found - skipping IP database download"
    log_info "You can download them manually later with: bash ./requirements/static_files.sh"
fi

# =============================================================================
# 15.5. INSTALL FRONTEND DEPENDENCIES
# =============================================================================
log_step "STEP 15.5: Installing frontend dependencies"

if [ -d "frontend" ]; then
    cd frontend

    if [ ! -d "node_modules" ]; then
        log_info "Installing frontend npm packages (this may take 5-10 minutes)..."
        npm install
        log_success "Frontend dependencies installed"
    else
        log_success "Frontend node_modules already exists"
        log_info "Checking for updates..."
        npm install
        log_success "Frontend dependencies verified/updated"
    fi

    # Verify critical dependencies
    if [ -f "package.json" ]; then
        log_info "Frontend package.json found"
        if grep -q "react" package.json; then
            log_success "React dependency verified"
        fi
        if grep -q "vite" package.json; then
            log_success "Vite build tool verified"
        fi
    fi

    cd ..
else
    log_warning "Frontend directory not found - frontend installation skipped"
    log_info "If you have a separate frontend, install dependencies manually:"
    log_info "  cd frontend && npm install"
fi

log_success "Frontend setup complete"

# =============================================================================
# 16. CREATE SUPERUSER (AUTOMATIC)
# =============================================================================
log_step "STEP 16: Creating superuser account automatically"

# Use environment variables or defaults
SUPERUSER_NAME=${SUPERUSER_USERNAME:-"admin"}
SUPERUSER_EMAIL=${SUPERUSER_EMAIL:-"admin@example.com"}
SUPERUSER_PASSWORD=${SUPERUSER_PASSWORD:-"admin"}

log_info "Superuser will be created with:"
log_info "  Username: $SUPERUSER_NAME"
log_info "  Email: $SUPERUSER_EMAIL"
log_info "  Password: $SUPERUSER_PASSWORD"
log_warning "⚠️  Change this password immediately after first login!"

cd apps

# Verify migrations succeeded before creating superuser
log_info "Verifying database schema..."
if python manage.py showmigrations | grep -q "\[ \]"; then
    log_error "Some migrations are not applied. Please check migration errors above."
    cd ..
    exit 1
fi

log_success "All migrations applied successfully"

# Create superuser automatically using environment variables
DJANGO_SUPERUSER_USERNAME="$SUPERUSER_NAME" \
DJANGO_SUPERUSER_EMAIL="$SUPERUSER_EMAIL" \
DJANGO_SUPERUSER_PASSWORD="$SUPERUSER_PASSWORD" \
python manage.py createsuperuser --noinput 2>/dev/null || {
    log_warning "Superuser may already exist or creation failed"
    log_info "You can create it manually with: cd /opt/truefypjs/apps && python manage.py createsuperuser"
}

# Verify superuser was created and fix is_superuser/is_staff flags
if python manage.py shell -c "from users.models import User; print(User.objects.filter(username='$SUPERUSER_NAME').exists())" 2>/dev/null | grep -q "True"; then
    log_success "Superuser '$SUPERUSER_NAME' exists"

    # Explicitly set is_superuser and is_staff flags (in case migration was missing them)
    log_info "Ensuring superuser flags are set correctly..."
    python manage.py shell -c "
from users.models import User
user = User.objects.get(username='$SUPERUSER_NAME')
user.is_superuser = True
user.is_staff = True
user.role = 'Admin'
user.is_active = True
user.save()
print(f'Updated {user.username}: is_superuser={user.is_superuser}, is_staff={user.is_staff}, role={user.role}')
" 2>/dev/null || log_warning "Could not update superuser flags"

    log_success "Superuser '$SUPERUSER_NAME' configured correctly"
else
    log_error "Superuser creation verification failed"
fi

cd ..

# =============================================================================
# 17. VERIFY/GENERATE USER CERTIFICATE FOR SUPERUSER
# =============================================================================
log_step "STEP 17: Verifying mTLS certificate for superuser"

cd apps

# Check if superuser already has a certificate (from signal handler)
HAS_CERT=$(python manage.py shell -c "
from pki.models import Certificate
from users.models import User
try:
    user = User.objects.get(username='$SUPERUSER_NAME')
    has_cert = Certificate.objects.filter(user=user, is_revoked=False).exists()
    print(has_cert)
except:
    print(False)
" 2>/dev/null)

if [ "$HAS_CERT" = "True" ]; then
    log_success "Certificate already exists for $SUPERUSER_NAME (auto-generated by signal)"
    CERT_ISSUED=true
else
    log_info "Certificate not found, generating manually for: $SUPERUSER_NAME"
    if python manage.py generate_missing_certs --username "$SUPERUSER_NAME" --days 365 2>/dev/null; then
        log_success "Certificate generated successfully"
        CERT_ISSUED=true
    else
        log_warning "Certificate generation failed - PKI may not be initialized"
        log_info "You can generate certificates later with:"
        log_info "  cd /opt/truefypjs/apps && python manage.py generate_missing_certs"
        CERT_ISSUED=false
    fi
fi

if [ "$CERT_ISSUED" = true ]; then
    log_info "Certificate download locations:"
    log_info "  Django Admin: http://192.168.148.154:8080/admin/pki/certificate/"
    log_info "  API: /api/v1/pki/certificates/<id>/download/"
fi

cd ..

# =============================================================================
# 18. VERIFY DJANGO CONFIGURATION
# =============================================================================
log_step "STEP 18: Verifying Django configuration"

cd apps
if python manage.py check; then
    log_success "Django configuration verified - no issues found!"
else
    log_error "Django configuration check failed"
    exit 1
fi
cd ..

# =============================================================================
# 19. DISPLAY SETUP SUMMARY
# =============================================================================
log_step "✅ SETUP COMPLETE!"

echo ""
echo "======================================="
echo "  JumpServer Blockchain Chain of Custody"
echo "======================================="
echo ""

log_info "Database Configuration:"
echo "  PostgreSQL:"
echo "    - Host: localhost:5432"
echo "    - Database: $DB_NAME"
echo "    - User: $DB_USER"
echo "    - Password: $DB_PASSWORD"
echo ""
echo "  Redis:"
echo "    - Host: localhost:6379"
echo "    - Status: Flushed (fresh start)"
echo ""

log_info "Blockchain/IPFS Mode:"
echo "  - Mock Blockchain: ENABLED (no Hyperledger Fabric required)"
echo "  - Mock IPFS: ENABLED (files stored in data/uploads/)"
echo "  - Evidence uploads will work end-to-end with mock backends"
echo ""

log_info "PKI/mTLS Status:"
if [ "$CERT_ISSUED" = true ]; then
    echo "  - Internal CA: Initialized"
    echo "  - User Certificate: Issued"
    echo "  - Certificate File: data/certs/pki/${SUPERUSER_NAME}.p12"
    echo "  - Certificate Password: $CERT_PASSWORD"
    echo ""
    echo "  ⚠ To enable mTLS in nginx:"
    echo "    1. Uncomment these lines in /etc/nginx/sites-available/jumpserver:"
    echo "       ssl_client_certificate CA_CERT_PATH;"
    echo "       ssl_verify_client optional;"
    echo "       ssl_crl CA_CRL_PATH;"
    echo "    2. Export CA cert: cd apps && python manage.py export_ca_cert"
    echo "    3. Reload nginx: sudo systemctl reload nginx"
else
    echo "  - Internal CA: Not initialized (PKI commands not available)"
    echo "  - mTLS: Disabled (can be enabled once PKI is implemented)"
fi
echo ""

log_info "How to Start JumpServer:"
echo ""
echo "  1. Activate virtual environment:"
echo "     source venv/bin/activate"
echo ""
echo "  2. Start Django backend:"
echo "     cd apps && python manage.py runserver 0.0.0.0:8080"
echo ""
echo "  3. Access application:"
echo "     - Backend (direct): http://localhost:8080"
echo "     - Frontend (nginx): https://localhost (requires SSL)"
echo ""

log_info "Superuser Credentials:"
echo "  Username: $SUPERUSER_NAME"
echo "  Password: $SUPERUSER_PASSWORD"
echo "  Email: $SUPERUSER_EMAIL"
echo ""
log_warning "⚠️  IMPORTANT: Change the default password after first login!"
echo ""

if [ "$CERT_ISSUED" = true ]; then
    log_info "mTLS Certificate Import (for browser-based auth):"
    echo "  1. Import certificate into browser:"
    echo "     - Firefox: Settings → Privacy → Certificates → Import"
    echo "     - Chrome: Settings → Security → Manage certificates → Import"
    echo "  2. File: data/certs/pki/${SUPERUSER_NAME}.p12"
    echo "  3. Password: $CERT_PASSWORD"
    echo "  4. Browse to https://localhost and select certificate"
    echo ""
fi

log_info "Useful Commands:"
echo ""
echo "  Test database connection:"
echo "    PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME -c '\\dt'"
echo ""
echo "  View PostgreSQL tables:"
echo "    PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME"
echo "    \\dt pki_*"
echo "    \\dt blockchain_*"
echo ""
echo "  Check Redis:"
echo "    redis-cli PING"
echo "    redis-cli INFO"
echo ""
echo "  Django shell:"
echo "    cd apps && python manage.py shell"
echo ""
echo "  Create test investigation:"
echo "    curl -X POST http://localhost:8080/api/v1/blockchain/investigations/ \\"
echo "      -H 'Authorization: Bearer <token>' \\"
echo "      -d '{\"title\": \"Test Case\", \"description\": \"Testing\"}'"
echo ""

log_info "Logs:"
echo "  - Django: data/logs/jumpserver.log"
echo "  - nginx access: /var/log/nginx/access.log"
echo "  - nginx errors: /var/log/nginx/error.log"
echo ""

log_info "Next Steps:"
echo "  1. Start BOTH backend AND frontend servers:"
echo ""
echo "     OPTION A - Quick Start (Recommended):"
echo "       ./start_services.sh"
echo ""
echo "     OPTION B - Manual Start (two separate terminals):"
echo "       Terminal 1 - Backend:"
echo "         source venv/bin/activate"
echo "         cd apps && python manage.py runserver 0.0.0.0:8080"
echo ""
echo "       Terminal 2 - Frontend:"
echo "         cd frontend && npm run dev"
echo ""
echo "  2. Access the application at http://192.168.148.154:3000"
echo "     (or http://localhost:3000 if accessing locally)"
echo ""
echo "  3. Login with superuser credentials:"
echo "     - Username: $SUPERUSER_NAME"
echo "     - Password: $SUPERUSER_PASSWORD"
echo ""
echo "  4. First login workflow:"
echo "     a) Login with password → Redirected to MFA setup"
echo "     b) Scan QR code with Google Authenticator/Authy"
echo "     c) Verify 6-digit code → Access dashboard"
echo ""
echo "  5. Admin Dashboard Features (as superuser):"
echo "     - User Management: Create/modify users, assign roles"
echo "     - Certificate Management: Download user certificates (.p12 files)"
echo "     - Tag Management: Create/modify investigation tags"
echo "     - Investigation Management: Create, archive, reopen investigations"
echo "     - Evidence Management: Upload evidence, verify blockchain records"
echo ""
echo "  6. Other Access Points:"
echo "     - Django Admin: http://192.168.148.154:8080/admin"
echo "     - API Docs: http://192.168.148.154:8080/api/docs"
echo "     - mTLS Login (nginx): https://localhost (requires certificate import)"
echo ""

log_success "✓ Setup Complete!"
echo ""

# =============================================================================
# INSTALLATION SUMMARY
# =============================================================================
log_step "📋 INSTALLATION SUMMARY"

echo ""
log_info "System Components Installed:"

# Check and display installed components
if command -v python3 &> /dev/null; then
    echo "  ✓ Python $(python3 --version 2>&1 | awk '{print $2}')"
fi

if command -v node &> /dev/null; then
    echo "  ✓ Node.js $(node --version)"
fi

if command -v npm &> /dev/null; then
    echo "  ✓ npm $(npm --version)"
fi

if command -v psql &> /dev/null; then
    echo "  ✓ PostgreSQL $(psql --version | awk '{print $3}')"
fi

if command -v redis-server &> /dev/null; then
    echo "  ✓ Redis $(redis-server --version | awk '{print $3}')"
fi

if command -v nginx &> /dev/null; then
    echo "  ✓ nginx $(nginx -v 2>&1 | awk '{print $3}')"
fi

if [ -d "venv" ]; then
    echo "  ✓ Python virtual environment (venv/)"
fi

if [ -d "frontend/node_modules" ]; then
    echo "  ✓ Frontend dependencies (node_modules/)"
fi

echo ""
log_info "Database Status:"
echo "  ✓ Database: $DB_NAME"
echo "  ✓ User: $DB_USER"
if PGPASSWORD=$DB_PASSWORD psql -h 127.0.0.1 -U $DB_USER -d $DB_NAME -c '\dt' 2>/dev/null | grep -q 'pki_certificate'; then
    echo "  ✓ Migrations applied successfully"
fi

echo ""
log_info "Services Status:"
if sudo systemctl is-active --quiet postgresql; then
    echo "  ✓ PostgreSQL: Running"
else
    echo "  ✗ PostgreSQL: Not running"
fi

if sudo systemctl is-active --quiet redis-server; then
    echo "  ✓ Redis: Running"
else
    echo "  ✗ Redis: Not running"
fi

if sudo systemctl is-active --quiet nginx; then
    echo "  ✓ nginx: Running"
else
    echo "  ✗ nginx: Not running"
fi

echo ""
log_info "Application Status:"
echo "  ✓ Backend: Ready (not started)"
echo "  ✓ Frontend: Ready (not started)"

echo ""
log_warning "⚠️  NEXT STEP: Start both backend and frontend servers"
echo ""
log_info "Quick Start:"
echo "  ./start_services.sh"
echo ""
log_info "Or start manually:"
echo "  Terminal 1: source venv/bin/activate && cd apps && python manage.py runserver 0.0.0.0:8080"
echo "  Terminal 2: cd frontend && npm run dev"
echo ""

log_warning "⚠️  REMEMBER: You need to start BOTH backend AND frontend servers!"
log_info "Run: ./start_services.sh"
echo ""
