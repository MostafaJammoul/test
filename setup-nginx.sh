#!/bin/bash
# =============================================================================
# Nginx Setup Script for JumpServer Blockchain Chain of Custody
# =============================================================================
# This script will:
# 1. Install nginx if not present
# 2. Create necessary directories
# 3. Generate SSL certificates (if not present)
# 4. Install nginx configuration
# 5. Enable and start nginx
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root or with sudo"
    echo "Usage: sudo ./setup-nginx.sh [dev|prod]"
    exit 1
fi

# Check argument
MODE=${1:-dev}
if [[ "$MODE" != "dev" && "$MODE" != "prod" ]]; then
    print_error "Invalid mode. Use 'dev' or 'prod'"
    echo "Usage: sudo ./setup-nginx.sh [dev|prod]"
    exit 1
fi

print_header "Nginx Setup for JumpServer ($MODE mode)"

# =============================================================================
# Step 1: Install nginx
# =============================================================================
print_header "Step 1: Installing nginx"

if command -v nginx &> /dev/null; then
    print_success "nginx is already installed: $(nginx -v 2>&1)"
else
    echo "Installing nginx..."
    apt-get update
    apt-get install -y nginx
    print_success "nginx installed"
fi

# =============================================================================
# Step 2: Create directories
# =============================================================================
print_header "Step 2: Creating directories"

# Certificate directories
mkdir -p /home/jsroot/js/data/certs/mtls/server-certs
mkdir -p /home/jsroot/js/data/certs/mtls/ca-certs
mkdir -p /home/jsroot/js/data/certs/mtls/client-certs
mkdir -p /home/jsroot/js/data/media
mkdir -p /home/jsroot/js/apps/static/frontend

# Set ownership
chown -R jsroot:jsroot /home/jsroot/js/data/certs
chown -R jsroot:jsroot /home/jsroot/js/data/media

print_success "Directories created"

# =============================================================================
# Step 3: Generate SSL certificates (if not present)
# =============================================================================
print_header "Step 3: Checking SSL certificates"

CERT_DIR="/home/jsroot/js/data/certs/mtls"
SERVER_CERT="$CERT_DIR/server-certs/server-cert.pem"
SERVER_KEY="$CERT_DIR/server-certs/server-key.pem"
CA_CERT="$CERT_DIR/ca-certs/ca-cert.pem"

if [ -f "$SERVER_CERT" ] && [ -f "$SERVER_KEY" ] && [ -f "$CA_CERT" ]; then
    print_success "SSL certificates already exist"
    echo "  Server Cert: $SERVER_CERT"
    echo "  Server Key: $SERVER_KEY"
    echo "  CA Cert: $CA_CERT"
else
    print_warning "SSL certificates not found. Generating self-signed certificates..."

    # Generate CA certificate
    openssl req -x509 -newkey rsa:4096 -keyout "$CERT_DIR/ca-certs/ca-key.pem" \
        -out "$CA_CERT" -days 3650 -nodes \
        -subj "/C=US/ST=State/L=City/O=JumpServer/OU=CA/CN=JumpServer Root CA"

    # Generate server private key
    openssl genrsa -out "$SERVER_KEY" 4096

    # Generate server CSR
    openssl req -new -key "$SERVER_KEY" \
        -out "$CERT_DIR/server-certs/server.csr" \
        -subj "/C=US/ST=State/L=City/O=JumpServer/OU=Server/CN=jumpserver.local"

    # Generate server certificate signed by CA
    openssl x509 -req -in "$CERT_DIR/server-certs/server.csr" \
        -CA "$CA_CERT" -CAkey "$CERT_DIR/ca-certs/ca-key.pem" \
        -CAcreateserial -out "$SERVER_CERT" -days 365 \
        -extfile <(printf "subjectAltName=DNS:jumpserver.local,DNS:localhost,IP:127.0.0.1,IP:$(hostname -I | awk '{print $1}')")

    # Set permissions
    chmod 600 "$SERVER_KEY" "$CERT_DIR/ca-certs/ca-key.pem"
    chmod 644 "$SERVER_CERT" "$CA_CERT"
    chown -R jsroot:jsroot "$CERT_DIR"

    print_success "SSL certificates generated"
    echo "  Server Cert: $SERVER_CERT"
    echo "  Server Key: $SERVER_KEY"
    echo "  CA Cert: $CA_CERT"

    print_warning "These are self-signed certificates for testing."
    print_warning "For production, replace with proper SSL certificates from a trusted CA."
fi

# =============================================================================
# Step 4: Install nginx configuration
# =============================================================================
print_header "Step 4: Installing nginx configuration"

if [ "$MODE" == "dev" ]; then
    CONFIG_SOURCE="/home/user/test/nginx-jumpserver-dev.conf"
    CONFIG_NAME="jumpserver-dev"
else
    CONFIG_SOURCE="/home/user/test/nginx-jumpserver-prod.conf"
    CONFIG_NAME="jumpserver"
fi

if [ ! -f "$CONFIG_SOURCE" ]; then
    print_error "Configuration file not found: $CONFIG_SOURCE"
    exit 1
fi

# Copy config to sites-available
cp "$CONFIG_SOURCE" "/etc/nginx/sites-available/$CONFIG_NAME"
print_success "Configuration copied to /etc/nginx/sites-available/$CONFIG_NAME"

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Create symlink to sites-enabled
ln -sf "/etc/nginx/sites-available/$CONFIG_NAME" "/etc/nginx/sites-enabled/$CONFIG_NAME"
print_success "Configuration enabled"

# =============================================================================
# Step 5: Test and reload nginx
# =============================================================================
print_header "Step 5: Testing nginx configuration"

if nginx -t; then
    print_success "nginx configuration is valid"

    # Reload nginx
    systemctl reload nginx || systemctl restart nginx
    print_success "nginx reloaded"
else
    print_error "nginx configuration test failed"
    exit 1
fi

# =============================================================================
# Step 6: Enable nginx to start on boot
# =============================================================================
systemctl enable nginx
print_success "nginx enabled to start on boot"

# =============================================================================
# Summary
# =============================================================================
print_header "Setup Complete!"

echo ""
echo -e "${GREEN}Nginx is now configured and running${NC}"
echo ""
echo "Mode: $MODE"
echo "Config: /etc/nginx/sites-available/$CONFIG_NAME"
echo "Logs:"
echo "  - Access: /var/log/nginx/jumpserver_${MODE}_access.log"
echo "  - Error: /var/log/nginx/jumpserver_${MODE}_error.log"
echo ""

if [ "$MODE" == "dev" ]; then
    echo -e "${YELLOW}DEVELOPMENT MODE:${NC}"
    echo "1. Start Django backend:"
    echo "   cd /home/user/test/apps"
    echo "   python manage.py runserver 0.0.0.0:8080"
    echo ""
    echo "2. Start React frontend:"
    echo "   cd /home/user/test/frontend"
    echo "   npm run dev"
    echo ""
    echo "3. Access via:"
    echo "   https://$(hostname -I | awk '{print $1}')/"
    echo "   https://localhost/"
else
    echo -e "${YELLOW}PRODUCTION MODE:${NC}"
    echo "1. Build React frontend:"
    echo "   cd /home/user/test/frontend"
    echo "   npm run build"
    echo ""
    echo "2. Start Django backend:"
    echo "   cd /home/user/test/apps"
    echo "   python manage.py runserver 0.0.0.0:8080"
    echo ""
    echo "3. Access via:"
    echo "   https://$(hostname -I | awk '{print $1}')/"
fi

echo ""
echo -e "${BLUE}Certificate Locations:${NC}"
echo "  Server Cert: $SERVER_CERT"
echo "  Server Key: $SERVER_KEY"
echo "  CA Cert: $CA_CERT"
echo ""
echo -e "${YELLOW}To generate client certificates for mTLS:${NC}"
echo "  See: /home/user/test/FYP-2/jumpserver-api/setup-mtls.sh"
echo ""
echo -e "${GREEN}Done!${NC}"
