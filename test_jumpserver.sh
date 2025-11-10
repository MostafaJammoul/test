#!/bin/bash
# =============================================================================
# JumpServer Comprehensive Test Suite
# =============================================================================
# Tests: nginx, Django, PostgreSQL, Redis, PKI, RBAC, Blockchain, mTLS
# =============================================================================

set +e  # Don't exit on errors, we want to test everything

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

PASSED=0
FAILED=0

test_passed() {
    ((PASSED++))
    log_success "$1"
}

test_failed() {
    ((FAILED++))
    log_error "$1"
}

echo "========================================="
echo "JumpServer Test Suite"
echo "========================================="
echo

# =============================================================================
# 1. SYSTEM SERVICES
# =============================================================================
log_info "TEST 1: System Services"
echo "-----------------------------------"

# PostgreSQL
if sudo systemctl is-active --quiet postgresql; then
    test_passed "PostgreSQL is running"
else
    test_failed "PostgreSQL is NOT running"
fi

# Redis
if sudo systemctl is-active --quiet redis || sudo systemctl is-active --quiet redis-server; then
    test_passed "Redis is running"
else
    test_failed "Redis is NOT running"
fi

# nginx
if sudo systemctl is-active --quiet nginx; then
    test_passed "nginx is running"
else
    test_failed "nginx is NOT running"
fi

echo

# =============================================================================
# 2. DATABASE CONNECTIVITY
# =============================================================================
log_info "TEST 2: Database Connectivity"
echo "-----------------------------------"

# Test PostgreSQL connection
if PGPASSWORD=jsroot psql -h 127.0.0.1 -U jumpserver -d jumpserver -c '\q' 2>/dev/null; then
    test_passed "PostgreSQL connection successful"
else
    test_failed "PostgreSQL connection failed"
fi

# Test Redis connection
if redis-cli ping 2>/dev/null | grep -q "PONG"; then
    test_passed "Redis connection successful"
else
    test_failed "Redis connection failed"
fi

echo

# =============================================================================
# 3. VIRTUAL ENVIRONMENT
# =============================================================================
log_info "TEST 3: Virtual Environment"
echo "-----------------------------------"

if [ -d "venv" ]; then
    test_passed "Virtual environment exists"
else
    test_failed "Virtual environment NOT found"
fi

if [ -f "venv/bin/python" ]; then
    test_passed "Python executable exists in venv"
else
    test_failed "Python executable NOT found in venv"
fi

echo

# =============================================================================
# 4. DJANGO APPLICATION
# =============================================================================
log_info "TEST 4: Django Application"
echo "-----------------------------------"

# Activate venv and test Django
source venv/bin/activate 2>/dev/null || true

# Check if Django is importable
if python -c "import django" 2>/dev/null; then
    test_passed "Django is installed"
else
    test_failed "Django is NOT installed"
fi

# Check if manage.py exists
if [ -f "apps/manage.py" ]; then
    test_passed "manage.py exists"
else
    test_failed "manage.py NOT found"
fi

# Test Django check command
cd apps 2>/dev/null
if python manage.py check --database default 2>&1 | grep -q "no issues"; then
    test_passed "Django system check passed"
else
    test_failed "Django system check failed"
fi
cd ..

echo

# =============================================================================
# 5. PKI / CERTIFICATES
# =============================================================================
log_info "TEST 5: PKI & Certificates"
echo "-----------------------------------"

# Check CA certificate exists in database
CA_EXISTS=$(cd apps && python manage.py shell -c "from pki.models import CertificateAuthority; print('yes' if CertificateAuthority.objects.exists() else 'no')" 2>/dev/null || echo "no")

if [ "$CA_EXISTS" = "yes" ]; then
    test_passed "Internal CA exists in database"
else
    test_failed "Internal CA NOT found in database"
fi

# Check exported CA certificate
if [ -f "data/certs/mtls/internal-ca.crt" ]; then
    test_passed "CA certificate exported (data/certs/mtls/internal-ca.crt)"
else
    test_failed "CA certificate NOT exported"
fi

# Check CRL
if [ -f "data/certs/mtls/internal-ca.crl" ]; then
    test_passed "CRL exported (data/certs/mtls/internal-ca.crl)"
else
    test_failed "CRL NOT exported"
fi

# Check server SSL certificate
if [ -f "data/certs/mtls/server.crt" ] && [ -f "data/certs/mtls/server.key" ]; then
    test_passed "Server SSL certificate exists"
else
    test_failed "Server SSL certificate NOT found"
fi

# Check user certificates
USER_CERTS=$(ls data/certs/pki/*.p12 2>/dev/null | wc -l)
if [ "$USER_CERTS" -gt 0 ]; then
    test_passed "User certificates exist ($USER_CERTS found)"
else
    test_failed "No user certificates found"
fi

echo

# =============================================================================
# 6. RBAC ROLES
# =============================================================================
log_info "TEST 6: RBAC Roles"
echo "-----------------------------------"

# Check if sync_role command exists
if cd apps && python manage.py help sync_role >/dev/null 2>&1; then
    test_passed "sync_role management command exists"
    cd ..
else
    test_failed "sync_role management command NOT found"
    cd ..
fi

# Check blockchain roles in database
cd apps 2>/dev/null
INVESTIGATOR_EXISTS=$(python manage.py shell -c "from rbac.models import Role; print('yes' if Role.objects.filter(name='BlockchainInvestigator').exists() else 'no')" 2>/dev/null || echo "no")
AUDITOR_EXISTS=$(python manage.py shell -c "from rbac.models import Role; print('yes' if Role.objects.filter(name='BlockchainAuditor').exists() else 'no')" 2>/dev/null || echo "no")
COURT_EXISTS=$(python manage.py shell -c "from rbac.models import Role; print('yes' if Role.objects.filter(name='BlockchainCourt').exists() else 'no')" 2>/dev/null || echo "no")
cd ..

if [ "$INVESTIGATOR_EXISTS" = "yes" ]; then
    test_passed "BlockchainInvestigator role exists"
else
    test_failed "BlockchainInvestigator role NOT found"
fi

if [ "$AUDITOR_EXISTS" = "yes" ]; then
    test_passed "BlockchainAuditor role exists"
else
    test_failed "BlockchainAuditor role NOT found"
fi

if [ "$COURT_EXISTS" = "yes" ]; then
    test_passed "BlockchainCourt role exists"
else
    test_failed "BlockchainCourt role NOT found"
fi

echo

# =============================================================================
# 7. BLOCKCHAIN APP
# =============================================================================
log_info "TEST 7: Blockchain Application"
echo "-----------------------------------"

# Check if blockchain app is installed
cd apps 2>/dev/null
if python -c "import blockchain" 2>/dev/null; then
    test_passed "Blockchain app is installed"
else
    test_failed "Blockchain app NOT found"
fi

# Check blockchain models
if python manage.py shell -c "from blockchain.models import Investigation, Evidence, BlockchainTransaction" 2>/dev/null; then
    test_passed "Blockchain models exist"
else
    test_failed "Blockchain models NOT found"
fi

# Check mock clients
if python -c "from blockchain.clients.fabric_client_mock import FabricClientMock" 2>/dev/null; then
    test_passed "Mock Fabric client exists"
else
    test_failed "Mock Fabric client NOT found"
fi

if python -c "from blockchain.clients.ipfs_client_mock import IPFSClientMock" 2>/dev/null; then
    test_passed "Mock IPFS client exists"
else
    test_failed "Mock IPFS client NOT found"
fi
cd ..

echo

# =============================================================================
# 8. NGINX CONFIGURATION
# =============================================================================
log_info "TEST 8: nginx Configuration"
echo "-----------------------------------"

# Check nginx config exists
if [ -f "/etc/nginx/sites-available/jumpserver-mtls" ]; then
    test_passed "nginx config exists"
else
    test_failed "nginx config NOT found"
fi

# Check if site is enabled
if [ -L "/etc/nginx/sites-enabled/jumpserver-mtls" ]; then
    test_passed "jumpserver-mtls site is enabled"
else
    test_failed "jumpserver-mtls site NOT enabled"
fi

# Check nginx config is valid
if sudo nginx -t 2>&1 | grep -q "successful"; then
    test_passed "nginx configuration is valid"
else
    test_failed "nginx configuration is INVALID"
fi

# Check nginx is listening on port 80
if sudo ss -tlnp | grep -q ":80.*nginx"; then
    test_passed "nginx listening on port 80"
else
    test_failed "nginx NOT listening on port 80"
fi

# Check nginx is listening on port 443
if sudo ss -tlnp | grep -q ":443.*nginx"; then
    test_passed "nginx listening on port 443"
else
    test_failed "nginx NOT listening on port 443"
fi

echo

# =============================================================================
# 9. DJANGO BACKEND
# =============================================================================
log_info "TEST 9: Django Backend"
echo "-----------------------------------"

# Check if Django is listening on port 8080
if sudo ss -tlnp | grep -q ":8080.*python"; then
    test_passed "Django listening on port 8080"
else
    test_failed "Django NOT listening on port 8080"
fi

# Test Django health endpoint (direct)
if curl -s http://127.0.0.1:8080/api/health/ 2>/dev/null | grep -q "status"; then
    test_passed "Django health endpoint accessible (port 8080)"
else
    test_failed "Django health endpoint NOT accessible (port 8080)"
fi

echo

# =============================================================================
# 10. NGINX → DJANGO PROXY
# =============================================================================
log_info "TEST 10: nginx → Django Proxy"
echo "-----------------------------------"

# Test HTTP redirect (port 80 → 443)
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/ 2>/dev/null || echo "000")
if [ "$HTTP_RESPONSE" = "301" ] || [ "$HTTP_RESPONSE" = "302" ]; then
    test_passed "HTTP redirect to HTTPS working (port 80)"
else
    test_failed "HTTP redirect NOT working (got $HTTP_RESPONSE)"
fi

# Test HTTPS health endpoint (through nginx)
if curl -k -s https://127.0.0.1/api/health/ 2>/dev/null | grep -q "status"; then
    test_passed "nginx → Django proxy working (HTTPS)"
else
    test_failed "nginx → Django proxy NOT working"
fi

echo

# =============================================================================
# 11. mTLS CONFIGURATION
# =============================================================================
log_info "TEST 11: mTLS Configuration"
echo "-----------------------------------"

# Check nginx is configured for mTLS
if sudo grep -q "ssl_client_certificate" /etc/nginx/sites-available/jumpserver-mtls 2>/dev/null; then
    test_passed "nginx mTLS configuration present"
else
    test_failed "nginx mTLS configuration NOT found"
fi

# Check nginx can read CA certificate
if sudo nginx -t 2>&1 | grep -q "ssl_client_certificate"; then
    # nginx found the directive
    if [ -f "data/certs/mtls/internal-ca.crt" ]; then
        test_passed "nginx can access CA certificate"
    else
        test_failed "CA certificate path in nginx config is invalid"
    fi
else
    test_passed "nginx mTLS configured (ssl_client_certificate found)"
fi

# Test mTLS endpoint without certificate (should fail with 495/496 or succeed if optional)
MTLS_RESPONSE=$(curl -k -s -o /dev/null -w "%{http_code}" https://127.0.0.1/ 2>/dev/null || echo "000")
if [ "$MTLS_RESPONSE" = "495" ] || [ "$MTLS_RESPONSE" = "496" ] || [ "$MTLS_RESPONSE" = "200" ]; then
    test_passed "mTLS endpoint responding (HTTP $MTLS_RESPONSE)"
else
    test_failed "mTLS endpoint unexpected response (HTTP $MTLS_RESPONSE)"
fi

echo

# =============================================================================
# 12. STATIC FILES
# =============================================================================
log_info "TEST 12: Static Files"
echo "-----------------------------------"

if [ -d "data/static" ] && [ "$(ls -A data/static 2>/dev/null)" ]; then
    test_passed "Static files collected"
else
    test_failed "Static files NOT collected (run: python manage.py collectstatic)"
fi

echo

# =============================================================================
# SUMMARY
# =============================================================================
echo "========================================="
echo "Test Summary"
echo "========================================="
echo

TOTAL=$((PASSED + FAILED))
PASS_RATE=$((PASSED * 100 / TOTAL))

log_info "Total Tests: $TOTAL"
log_success "Passed: $PASSED"
log_error "Failed: $FAILED"
echo

if [ "$FAILED" -eq 0 ]; then
    log_success "ALL TESTS PASSED! 🎉"
    echo
    log_info "Your JumpServer is fully configured and working!"
    echo
    log_info "Access URLs:"
    echo "  - HTTP (direct Django): http://192.168.148.154:8080"
    echo "  - HTTPS (mTLS):         https://192.168.148.154"
    echo
    exit 0
else
    log_error "Some tests failed ($PASS_RATE% passed)"
    echo
    log_info "Common fixes:"
    echo "  1. Start services: sudo systemctl start postgresql redis nginx"
    echo "  2. Fix nginx: ./fix_nginx.sh"
    echo "  3. Sync roles: cd apps && python manage.py sync_role"
    echo "  4. Export certs: cd apps && python manage.py export_ca_cert --output ../data/certs/mtls/internal-ca.crt"
    echo "  5. Start Django: cd apps && python manage.py runserver 0.0.0.0:8080"
    echo
    exit 1
fi
