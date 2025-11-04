#!/bin/bash
# =============================================================================
# JumpServer Blockchain Chain of Custody - Ubuntu Setup Script
# =============================================================================
# This script sets up the complete environment for testing with mock blockchain
# and IPFS backends (no real Fabric or IPFS required).
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
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# 1. CHECK PREREQUISITES
# =============================================================================
log_info "Step 1: Checking prerequisites..."

# Check Python version
if ! command -v python3.11 &> /dev/null; then
    log_error "Python 3.11+ not found. Installing..."
    sudo apt update
    sudo apt install -y software-properties-common
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt update
    sudo apt install -y python3.11 python3.11-venv python3.11-dev
fi

PYTHON_VERSION=$(python3.11 --version 2>&1 | awk '{print $2}')
log_success "Python version: $PYTHON_VERSION"

# Check if we're in the right directory
if [ ! -f "pyproject.toml" ]; then
    log_error "pyproject.toml not found. Please run this script from the truefypjs directory."
    exit 1
fi

log_success "Prerequisites checked"

# =============================================================================
# 2. INSTALL SYSTEM DEPENDENCIES
# =============================================================================
log_info "Step 2: Installing system dependencies..."

sudo apt update
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
    libz-dev \
    pkg-config \
    redis-server \
    gettext

log_success "System dependencies installed"

# =============================================================================
# 3. SETUP POSTGRESQL DATABASE
# =============================================================================
log_info "Step 3: Setting up PostgreSQL database..."

# Install PostgreSQL
if ! command -v psql &> /dev/null; then
    log_info "Installing PostgreSQL..."
    sudo apt install -y postgresql postgresql-contrib
    log_success "PostgreSQL installed"
else
    log_success "PostgreSQL already installed"
fi

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql
log_success "PostgreSQL service started"

# Create database and user (read from config.yml)
DB_NAME="jumpserver"
DB_USER="jumpserver"
DB_PASSWORD="jsroot"

log_info "Creating database: $DB_NAME"
log_info "Creating user: $DB_USER"

# Check if database already exists
if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    log_success "Database '$DB_NAME' already exists"
else
    sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER DATABASE $DB_NAME OWNER TO $DB_USER;
\q
EOF
    log_success "Database '$DB_NAME' created with user '$DB_USER'"
fi

# Test connection
if PGPASSWORD=$DB_PASSWORD psql -h 127.0.0.1 -U $DB_USER -d $DB_NAME -c '\q' 2>/dev/null; then
    log_success "PostgreSQL connection verified"
else
    log_error "PostgreSQL connection failed. Check credentials in config.yml"
    exit 1
fi

# =============================================================================
# 4. CREATE VIRTUAL ENVIRONMENT
# =============================================================================
log_info "Step 4: Setting up virtual environment..."

if [ -d "venv" ]; then
    log_success "Virtual environment already exists. Reusing it."
    source venv/bin/activate
else
    log_info "Creating new virtual environment..."
    python3.11 -m venv venv
    source venv/bin/activate
    log_success "Virtual environment created and activated"
fi

# =============================================================================
# 5. UPGRADE PIP
# =============================================================================
log_info "Step 5: Upgrading pip..."

pip install --upgrade pip setuptools wheel

log_success "Pip upgraded"

# =============================================================================
# 6. INSTALL PYTHON DEPENDENCIES
# =============================================================================
log_info "Step 6: Installing Python dependencies (this may take 5-10 minutes)..."

# Install dependencies from pyproject.toml
pip install -e .

log_success "Python dependencies installed"

# =============================================================================
# 7. START REDIS SERVER
# =============================================================================
log_info "Step 7: Starting Redis server..."

if ! pgrep -x "redis-server" > /dev/null; then
    sudo systemctl start redis-server
    sudo systemctl enable redis-server
    log_success "Redis server started"
else
    log_success "Redis server already running"
fi

# Test Redis connection
if redis-cli ping | grep -q "PONG"; then
    log_success "Redis connection verified"
else
    log_error "Redis connection failed"
    exit 1
fi

# =============================================================================
# 8. CREATE DATA DIRECTORIES
# =============================================================================
log_info "Step 8: Creating data directories..."

mkdir -p data/logs
mkdir -p data/media
mkdir -p data/static
mkdir -p data/certs/pki  # For PKI certificates
mkdir -p data/certs/mtls  # For mTLS exported certificates
mkdir -p data/uploads  # For evidence files (mock IPFS storage)

log_success "Data directories created"

# =============================================================================
# 9. GENERATE SECRET KEY (if not already set)
# =============================================================================
log_info "Step 9: Checking SECRET_KEY in config.yml..."

if grep -q "SECRET_KEY:" config.yml && ! grep -q "SECRET_KEY: $" config.yml; then
    log_success "SECRET_KEY already configured"
else
    log_info "Generating random SECRET_KEY..."
    SECRET_KEY=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*()_+' | head -c 50)
    sed -i "s/^SECRET_KEY:.*/SECRET_KEY: $SECRET_KEY/" config.yml
    log_success "SECRET_KEY generated and saved to config.yml"
fi

if grep -q "BOOTSTRAP_TOKEN:" config.yml && ! grep -q "BOOTSTRAP_TOKEN: $" config.yml; then
    log_success "BOOTSTRAP_TOKEN already configured"
else
    log_info "Generating random BOOTSTRAP_TOKEN..."
    BOOTSTRAP_TOKEN=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 40)
    sed -i "s/^BOOTSTRAP_TOKEN:.*/BOOTSTRAP_TOKEN: $BOOTSTRAP_TOKEN/" config.yml
    log_success "BOOTSTRAP_TOKEN generated and saved to config.yml"
fi

# =============================================================================
# 10. CREATE MIGRATIONS
# =============================================================================
log_info "Step 10: Creating database migrations..."

cd apps && python manage.py makemigrations pki
cd apps && python manage.py makemigrations blockchain
cd apps && python manage.py makemigrations

log_success "Migrations created"

# =============================================================================
# 11. RUN MIGRATIONS
# =============================================================================
log_info "Step 11: Running database migrations..."

cd apps && python manage.py migrate

log_success "Database migrations completed"

# =============================================================================
# 12. INITIALIZE PKI (Internal CA)
# =============================================================================
log_info "Step 12: Initializing PKI (Internal Certificate Authority)..."

if cd apps && python manage.py init_pki; then
    log_success "Internal CA initialized"
    log_info "CA certificate stored in database (apps/pki/models.py)"
else
    log_warning "PKI initialization failed or already initialized"
fi

# =============================================================================
# 13. EXPORT PKI CERTIFICATES FOR NGINX (mTLS Setup)
# =============================================================================
log_info "Step 13: Exporting PKI certificates for nginx..."

# Export CA certificate
cd apps && python manage.py export_ca_cert --output ../data/certs/mtls/internal-ca.crt

# Export CRL (Certificate Revocation List)
cd apps && python manage.py export_crl --output ../data/certs/mtls/internal-ca.crl

log_success "PKI certificates exported for nginx"

# =============================================================================
# 14. INSTALL AND CONFIGURE NGINX (mTLS)
# =============================================================================
log_info "Step 14: Installing and configuring nginx for mTLS..."

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
    sudo mkdir -p /etc/nginx/ssl
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout data/certs/mtls/server.key \
        -out data/certs/mtls/server.crt \
        -subj "/C=US/ST=California/L=San Francisco/O=JumpServer/OU=Testing/CN=localhost" \
        2>/dev/null

    chmod 600 data/certs/mtls/server.key
    chmod 644 data/certs/mtls/server.crt
    log_success "Server SSL certificate generated"
fi

# Copy nginx configuration
NGINX_CONF="/etc/nginx/sites-available/jumpserver-mtls"
if [ ! -f "$NGINX_CONF" ]; then
    log_info "Copying nginx mTLS configuration..."
    sudo cp config/nginx-mtls.conf.example "$NGINX_CONF"

    # Update paths in nginx config
    CURRENT_DIR=$(pwd)
    sudo sed -i "s|/etc/letsencrypt/live/jumpserver.example.com/fullchain.pem|$CURRENT_DIR/data/certs/mtls/server.crt|g" "$NGINX_CONF"
    sudo sed -i "s|/etc/letsencrypt/live/jumpserver.example.com/privkey.pem|$CURRENT_DIR/data/certs/mtls/server.key|g" "$NGINX_CONF"
    sudo sed -i "s|/etc/nginx/ssl/internal-ca.crt|$CURRENT_DIR/data/certs/mtls/internal-ca.crt|g" "$NGINX_CONF"
    sudo sed -i "s|/etc/nginx/ssl/internal-ca.crl|$CURRENT_DIR/data/certs/mtls/internal-ca.crl|g" "$NGINX_CONF"
    sudo sed -i "s|/path/to/jumpserver/data/static/|$CURRENT_DIR/data/static/|g" "$NGINX_CONF"
    sudo sed -i "s|/path/to/jumpserver/data/media/|$CURRENT_DIR/data/media/|g" "$NGINX_CONF"

    log_success "nginx configuration copied and updated"
else
    log_success "nginx configuration already exists"
fi

# Enable site (but don't activate mTLS yet)
if [ ! -L "/etc/nginx/sites-enabled/jumpserver-mtls" ]; then
    sudo ln -s "$NGINX_CONF" /etc/nginx/sites-enabled/jumpserver-mtls 2>/dev/null || true
fi

# Test nginx configuration
if sudo nginx -t 2>/dev/null; then
    log_success "nginx configuration valid"

    # Reload nginx
    sudo systemctl reload nginx 2>/dev/null || sudo systemctl start nginx
    log_success "nginx reloaded"
else
    log_warning "nginx configuration test failed. Check /var/log/nginx/error.log"
    log_warning "Continuing without nginx (mTLS will not be available)"
fi

# =============================================================================
# 15. CONFIGURE MTLS IN JUMPSERVER
# =============================================================================
log_info "Step 15: Configuring mTLS in JumpServer..."

# Enable mTLS in config.yml
sed -i 's/MTLS_ENABLED: false/MTLS_ENABLED: true/' config.yml

log_success "mTLS enabled in config.yml"
log_info "nginx is now configured to require client certificates"
log_info "Access JumpServer at: https://localhost"

# =============================================================================
# 16. ISSUE SUPERUSER CERTIFICATE FOR TESTING
# =============================================================================
log_info "Step 16: You will be prompted to create a superuser..."
log_info "After creating the superuser, we'll issue a certificate for mTLS testing."

# =============================================================================
# 17. SYNC BUILTIN ROLES (Including Blockchain Roles)
# =============================================================================
log_info "Step 17: Syncing builtin roles..."

cd apps && python manage.py sync_role

log_success "Builtin roles synced (including BlockchainInvestigator, BlockchainAuditor, BlockchainCourt)"

# =============================================================================
# 18. CREATE SUPERUSER
# =============================================================================
log_info "Step 18: Creating superuser..."

echo ""
log_warning "You will be prompted to create a superuser account."
log_info "This account will have full admin access to JumpServer."
echo ""

# Ask for username first
read -p "Enter superuser username: " SUPERUSER_NAME

cd apps && python manage.py createsuperuser --username "$SUPERUSER_NAME"

log_success "Superuser created: $SUPERUSER_NAME"

# Issue certificate for superuser
log_info "Issuing mTLS certificate for superuser: $SUPERUSER_NAME..."

CERT_PASSWORD="changeme123"
cd apps && python manage.py issue_user_cert \
    --username "$SUPERUSER_NAME" \
    --output "../data/certs/pki/${SUPERUSER_NAME}.p12" \
    --password "$CERT_PASSWORD"

log_success "Certificate issued: data/certs/pki/${SUPERUSER_NAME}.p12"
log_info "Certificate password: $CERT_PASSWORD"
echo ""
log_warning "⚠ IMPORTANT: Import this certificate into your browser to access via mTLS"
echo "  1. Firefox: Settings → Privacy & Security → Certificates → Import"
echo "  2. Chrome: Settings → Privacy and security → Manage certificates → Import"
echo "  3. File: data/certs/pki/${SUPERUSER_NAME}.p12"
echo "  4. Password: $CERT_PASSWORD"
echo ""

# =============================================================================
# 19. COLLECT STATIC FILES
# =============================================================================
log_info "Step 19: Collecting static files..."

cd apps && python manage.py collectstatic --noinput

log_success "Static files collected"

# =============================================================================
# 20. VERIFY CONFIGURATION
# =============================================================================
log_info "Step 20: Verifying configuration..."

echo ""
log_info "Configuration Summary:"
echo "  - Database: PostgreSQL (jumpserver@localhost:5432/jumpserver)"
echo "  - Redis: localhost:6379"
echo "  - Mock Blockchain: ENABLED (no real Fabric required)"
echo "  - Mock IPFS: ENABLED (no real IPFS required)"
echo "  - PKI: ENABLED (Internal CA initialized)"
echo "  - mTLS: ENABLED (nginx configured with client cert verification)"
echo "  - nginx: RUNNING (https://localhost)"
echo ""

# Check Django configuration
if cd apps && python manage.py check; then
    log_success "Django configuration verified"
else
    log_error "Django configuration check failed"
    exit 1
fi

# =============================================================================
# 21. DISPLAY CERTIFICATE STORAGE LOCATIONS
# =============================================================================
echo ""
log_info "Certificate Storage Locations:"
echo "  ✓ Database Storage (Primary):"
echo "    - Table: pki_certificateauthority (CA cert + private key, encrypted)"
echo "    - Table: pki_certificate (User certs + private keys, encrypted)"
echo "    - Location: PostgreSQL (jumpserver@localhost:5432/jumpserver)"
echo ""
echo "  ✓ Filesystem Export (For nginx mTLS):"
echo "    - CA Certificate: data/certs/mtls/internal-ca.crt ✓ EXPORTED"
echo "    - CA CRL: data/certs/mtls/internal-ca.crl ✓ EXPORTED"
echo "    - Server SSL: data/certs/mtls/server.crt ✓ GENERATED"
echo "    - User P12: data/certs/pki/${SUPERUSER_NAME}.p12 ✓ ISSUED"
echo ""

# =============================================================================
# 22. START SERVER
# =============================================================================
echo ""
log_success "======================================="
log_success "Setup Complete! 🎉"
log_success "======================================="
echo ""

log_info "JumpServer Backend:"
echo ""
echo "  Start backend server:"
echo "    source venv/bin/activate"
echo "    python manage.py runserver 0.0.0.0:8080"
echo ""

log_info "Access JumpServer:"
echo ""
echo "  🔒 WITH mTLS (HTTPS - Certificate Required):"
echo "    https://localhost"
echo ""
echo "  ⚠ Import certificate FIRST:"
echo "    1. Import: data/certs/pki/${SUPERUSER_NAME}.p12"
echo "    2. Password: $CERT_PASSWORD"
echo "    3. Browser will prompt for certificate selection"
echo "    4. You'll be auto-authenticated as: $SUPERUSER_NAME"
echo ""
echo "  🔓 WITHOUT mTLS (HTTP - Direct Backend):"
echo "    http://localhost:8080"
echo "    (For testing without certificate)"
echo ""

log_info "Testing mTLS Authentication:"
echo ""
echo "  1. Import certificate into browser (see above)"
echo "  2. Visit: https://localhost"
echo "  3. Browser prompts for certificate → Select ${SUPERUSER_NAME}"
echo "  4. Automatically logged in!"
echo ""
echo "  Test with curl:"
echo "    curl https://localhost/api/health/ \\"
echo "      --cert data/certs/pki/${SUPERUSER_NAME}.p12 \\"
echo "      --cert-type P12 \\"
echo "      --pass \"$CERT_PASSWORD\""
echo ""

log_info "Testing Blockchain Features (Mock Mode):"
echo ""
echo "  1. Create user with BlockchainInvestigator role:"
echo "     - Navigate to: Users → Create User"
echo "     - Assign role: BlockchainInvestigator"
echo ""
echo "  2. Create investigation:"
echo "     - API: POST /api/v1/blockchain/investigations/"
echo "     - Payload: {\"title\": \"Test Case\", \"description\": \"Testing\"}"
echo ""
echo "  3. Upload evidence:"
echo "     - API: POST /api/v1/blockchain/evidence/"
echo "     - Files stored in: data/uploads/ (mock IPFS)"
echo "     - Blockchain txs recorded in database (mock Fabric)"
echo ""

log_info "Logs:"
echo ""
echo "  - JumpServer: data/logs/jumpserver.log"
echo "  - nginx: /var/log/nginx/jumpserver-mtls.log"
echo "  - nginx errors: /var/log/nginx/error.log"
echo ""

log_warning "Starting backend server in 5 seconds... (Press Ctrl+C to cancel)"
log_info "nginx is already running on https://localhost"
sleep 5

log_info "Starting JumpServer backend on http://localhost:8080..."
cd apps && python manage.py runserver 0.0.0.0:8080
