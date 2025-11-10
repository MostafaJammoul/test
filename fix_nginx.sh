#!/bin/bash
# =============================================================================
# Quick nginx Fix Script
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
echo "nginx Quick Fix"
echo "========================================="
echo

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    log_error "nginx is not installed!"
    log_info "Installing nginx..."
    sudo apt update
    sudo apt install -y nginx
    log_success "nginx installed"
fi

# Check if nginx is running
if sudo systemctl is-active --quiet nginx; then
    log_success "nginx is running"
else
    log_warning "nginx is NOT running"
    log_info "Starting nginx..."
    sudo systemctl start nginx
    sudo systemctl enable nginx
    log_success "nginx started and enabled"
fi

# Check if jumpserver-mtls config exists
NGINX_CONF="/etc/nginx/sites-available/jumpserver-mtls"
if [ ! -f "$NGINX_CONF" ]; then
    log_error "nginx config not found: $NGINX_CONF"
    log_info "Run fix_setup.sh to create nginx configuration"
    exit 1
fi

# Check if site is enabled
if [ ! -L "/etc/nginx/sites-enabled/jumpserver-mtls" ]; then
    log_warning "jumpserver-mtls not enabled"
    log_info "Enabling site..."
    sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    log_success "Site enabled"
fi

# Remove default site if it exists
if [ -L "/etc/nginx/sites-enabled/default" ]; then
    log_info "Removing default nginx site..."
    sudo rm /etc/nginx/sites-enabled/default
    log_success "Default site removed"
fi

# Test nginx configuration
log_info "Testing nginx configuration..."
if sudo nginx -t 2>&1; then
    log_success "nginx configuration is valid"
else
    log_error "nginx configuration test failed!"
    log_info "Check errors above and fix /etc/nginx/sites-available/jumpserver-mtls"
    exit 1
fi

# Reload nginx
log_info "Reloading nginx..."
sudo systemctl reload nginx
log_success "nginx reloaded"

echo
echo "========================================="
log_success "nginx Fixed!"
echo "========================================="
echo

# Show nginx status
log_info "nginx Status:"
sudo systemctl status nginx --no-pager | head -n 10

echo
log_info "nginx Listening Ports:"
sudo ss -tlnp | grep nginx || log_warning "nginx not listening on any ports yet"

echo
log_info "Test nginx:"
echo "  curl -k http://localhost"
echo "  curl -k https://localhost/api/health/"
echo
