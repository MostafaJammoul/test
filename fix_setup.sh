#!/bin/bash
# =============================================================================
# JumpServer Fix Script - Diagnose and repair setup issues
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "========================================="
echo "JumpServer Setup Diagnostic & Fix"
echo "========================================="
echo

# =============================================================================
# 1. CHECK VIRTUAL ENVIRONMENT
# =============================================================================
log_info "Step 1: Checking virtual environment..."

if [ ! -d "venv" ]; then
    log_error "Virtual environment not found!"
    log_info "Creating virtual environment..."
    python3.11 -m venv venv
    log_success "Virtual environment created"
fi

source venv/bin/activate
log_success "Virtual environment activated"

# =============================================================================
# 2. CHECK DJANGO INSTALLATION
# =============================================================================
log_info "Step 2: Checking Django installation..."

if ! python -c "import django" 2>/dev/null; then
    log_error "Django not installed!"
    log_info "Installing dependencies..."
    pip install -e .
    log_success "Dependencies installed"
else
    log_success "Django is installed"
fi

# =============================================================================
# 3. CREATE CERTIFICATE DIRECTORIES
# =============================================================================
log_info "Step 3: Creating certificate directories..."

mkdir -p data/logs
mkdir -p data/media
mkdir -p data/static
mkdir -p data/certs/pki
mkdir -p data/certs/mtls
mkdir -p data/uploads
mkdir -p data/mock_ipfs
mkdir -p data/mock_blockchain/hot
mkdir -p data/mock_blockchain/cold

log_success "Directories created"

# =============================================================================
# 4. CHECK DATABASE
# =============================================================================
log_info "Step 4: Checking database..."

if PGPASSWORD=jsroot psql -h 127.0.0.1 -U jumpserver -d jumpserver -c '\q' 2>/dev/null; then
    log_success "PostgreSQL connection OK"
else
    log_error "PostgreSQL connection failed!"
    log_info "Checking PostgreSQL status..."
    sudo systemctl status postgresql --no-pager || true
    exit 1
fi

# =============================================================================
# 5. RUN MIGRATIONS
# =============================================================================
log_info "Step 5: Running migrations..."

cd apps
python manage.py makemigrations pki 2>/dev/null || true
python manage.py makemigrations blockchain 2>/dev/null || true
python manage.py makemigrations 2>/dev/null || true
python manage.py migrate

log_success "Migrations completed"

# =============================================================================
# 6. CREATE SYSTEM DIRECTORIES FOR PKI
# =============================================================================
log_info "Step 6: Creating system directories for PKI..."

# Create /etc/jumpserver/certs/internal-ca with proper permissions
if [ ! -d "/etc/jumpserver/certs/internal-ca" ]; then
    log_info "Creating /etc/jumpserver/certs/internal-ca..."
    sudo mkdir -p /etc/jumpserver/certs/internal-ca
    sudo chown -R $USER:$USER /etc/jumpserver
    sudo chmod -R 755 /etc/jumpserver
    log_success "Created /etc/jumpserver/certs/internal-ca"
else
    log_success "/etc/jumpserver/certs/internal-ca already exists"
fi

# Create /etc/nginx/ssl with proper permissions
if [ ! -d "/etc/nginx/ssl" ]; then
    log_info "Creating /etc/nginx/ssl..."
    sudo mkdir -p /etc/nginx/ssl
    sudo chown -R $USER:$USER /etc/nginx/ssl
    sudo chmod 755 /etc/nginx/ssl
    log_success "Created /etc/nginx/ssl"
else
    log_success "/etc/nginx/ssl already exists"
fi

# =============================================================================
# 7. INITIALIZE PKI (CA)
# =============================================================================
log_info "Step 7: Checking PKI initialization..."

CA_EXISTS=$(python manage.py shell -c "from pki.models import CertificateAuthority; print('yes' if CertificateAuthority.objects.exists() else 'no')" 2>/dev/null || echo "no")

if [ "$CA_EXISTS" = "no" ]; then
    log_warning "CA not found! Initializing PKI..."
    python manage.py init_pki
    log_success "PKI initialized"
else
    log_success "CA already exists"
fi

# =============================================================================
# 8. EXPORT CA CERTIFICATE FOR NGINX
# =============================================================================
log_info "Step 8: Exporting CA certificate for nginx..."

cd ..
python apps/manage.py export_ca_cert --output data/certs/mtls/internal-ca.crt --force
python apps/manage.py export_crl --output data/certs/mtls/internal-ca.crl --force

log_success "CA certificate exported"

# =============================================================================
# 9. GENERATE SERVER SSL CERTIFICATE
# =============================================================================
log_info "Step 9: Generating server SSL certificate..."

if [ ! -f "data/certs/mtls/server.crt" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout data/certs/mtls/server.key \
        -out data/certs/mtls/server.crt \
        -subj "/C=US/ST=California/L=San Francisco/O=JumpServer/OU=Testing/CN=192.168.148.154" \
        2>/dev/null

    chmod 600 data/certs/mtls/server.key
    chmod 644 data/certs/mtls/server.crt
    log_success "Server SSL certificate generated"
else
    log_success "Server SSL certificate exists"
fi

# =============================================================================
# 10. LIST ALL USERS
# =============================================================================
log_info "Step 10: Listing existing users..."

cd apps
python manage.py shell << 'EOF'
from users.models import User
users = User.objects.all()
print("\n=== Existing Users ===")
for user in users:
    print(f"  - Username: {user.username}")
    print(f"    Email: {user.email}")
    print(f"    Is superuser: {user.is_superuser}")
    print()
EOF

cd ..

# =============================================================================
# 11. ISSUE CERTIFICATE FOR FIRST SUPERUSER
# =============================================================================
log_info "Step 11: Checking for user certificates..."

FIRST_USER=$(cd apps && python manage.py shell -c "from users.models import User; u = User.objects.filter(is_superuser=True).first(); print(u.username if u else '')" 2>/dev/null || echo "")

if [ -n "$FIRST_USER" ]; then
    log_info "Found superuser: $FIRST_USER"

    if [ ! -f "data/certs/pki/${FIRST_USER}.p12" ]; then
        log_info "Issuing certificate for: $FIRST_USER"
        cd apps
        python manage.py issue_user_cert \
            --username "$FIRST_USER" \
            --output "../data/certs/pki/${FIRST_USER}.p12" \
            --password "changeme123"
        cd ..
        log_success "Certificate issued: data/certs/pki/${FIRST_USER}.p12"
        log_success "Password: changeme123"
    else
        log_success "Certificate already exists for: $FIRST_USER"
    fi
else
    log_warning "No superuser found! Create one with: cd apps && python manage.py createsuperuser"
fi

# =============================================================================
# 12. CHECK NGINX
# =============================================================================
log_info "Step 12: Checking nginx configuration..."

if command -v nginx &> /dev/null; then
    log_success "nginx is installed"

    # Check if jumpserver-mtls config exists
    NGINX_CONF="/etc/nginx/sites-available/jumpserver-mtls"
    if [ -f "$NGINX_CONF" ]; then
        log_success "nginx config exists: $NGINX_CONF"

        # Check if enabled
        if [ -L "/etc/nginx/sites-enabled/jumpserver-mtls" ]; then
            log_success "nginx config is enabled"
        else
            log_warning "nginx config not enabled!"
            log_info "Enable with: sudo ln -s $NGINX_CONF /etc/nginx/sites-enabled/"
        fi
    else
        log_warning "nginx config not found!"
        log_info "Creating nginx configuration..."

        CURRENT_DIR=$(pwd)
        sudo tee $NGINX_CONF > /dev/null << NGINXCONF
upstream jumpserver {
    server 127.0.0.1:8080;
}

server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    # Server SSL certificate (for HTTPS)
    ssl_certificate ${CURRENT_DIR}/data/certs/mtls/server.crt;
    ssl_certificate_key ${CURRENT_DIR}/data/certs/mtls/server.key;

    # Client certificate verification (mTLS)
    ssl_client_certificate ${CURRENT_DIR}/data/certs/mtls/internal-ca.crt;
    ssl_crl ${CURRENT_DIR}/data/certs/mtls/internal-ca.crl;
    ssl_verify_client optional;  # Set to 'on' to enforce mTLS
    ssl_verify_depth 2;

    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Pass client certificate info to backend
    proxy_set_header X-SSL-Client-Cert \$ssl_client_cert;
    proxy_set_header X-SSL-Client-DN \$ssl_client_s_dn;
    proxy_set_header X-SSL-Client-Verify \$ssl_client_verify;

    # Logging
    access_log /var/log/nginx/jumpserver-mtls.log;
    error_log /var/log/nginx/jumpserver-mtls-error.log;

    location / {
        proxy_pass http://jumpserver;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static/ {
        alias ${CURRENT_DIR}/data/static/;
    }

    location /media/ {
        alias ${CURRENT_DIR}/data/media/;
    }
}
NGINXCONF

        log_success "nginx config created"

        # Enable it
        sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/
        log_success "nginx config enabled"
    fi

    # Remove default site if exists
    if [ -L "/etc/nginx/sites-enabled/default" ]; then
        log_info "Removing default nginx site..."
        sudo rm /etc/nginx/sites-enabled/default
        log_success "Default site removed"
    fi

    # Test configuration
    if sudo nginx -t 2>/dev/null; then
        log_success "nginx configuration is valid"

        # Reload nginx
        sudo systemctl reload nginx
        log_success "nginx reloaded"
    else
        log_error "nginx configuration test failed!"
        sudo nginx -t
    fi
else
    log_error "nginx is not installed!"
    log_info "Install with: sudo apt install -y nginx"
fi

# =============================================================================
# 13. COLLECT STATIC FILES
# =============================================================================
# Note: Builtin roles (including blockchain roles) are automatically synced
# during migrations, so no separate sync_role command is needed.
log_info "Step 13: Collecting static files..."

cd apps
python manage.py collectstatic --noinput --clear
cd ..

log_success "Static files collected"

# =============================================================================
# 14. SUMMARY
# =============================================================================
echo
echo "========================================="
log_success "Setup Fixed!"
echo "========================================="
echo

log_info "Certificate Locations:"
echo "  - CA cert: data/certs/mtls/internal-ca.crt"
echo "  - CA CRL:  data/certs/mtls/internal-ca.crl"
echo "  - Server SSL: data/certs/mtls/server.crt"
if [ -n "$FIRST_USER" ]; then
    echo "  - User cert: data/certs/pki/${FIRST_USER}.p12 (password: changeme123)"
fi
echo

log_info "Start Django backend:"
echo "  source venv/bin/activate"
echo "  cd apps"
echo "  python manage.py runserver 0.0.0.0:8080"
echo

log_info "Access URLs:"
echo "  - HTTP (direct):  http://192.168.148.154:8080"
echo "  - HTTPS (mTLS):   https://192.168.148.154"
echo

log_info "Check nginx status:"
echo "  sudo systemctl status nginx"
echo

log_success "Done! 🎉"
