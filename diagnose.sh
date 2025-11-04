#!/bin/bash
# =============================================================================
# JumpServer Diagnostic Script
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OK="${GREEN}✅${NC}"
FAIL="${RED}❌${NC}"
WARN="${YELLOW}⚠${NC}"

echo "========================================="
echo "JumpServer Diagnostic"
echo "========================================="
echo

# =============================================================================
# 1. Check virtual environment
# =============================================================================
echo -n "Virtual environment... "
if [ -d "venv" ]; then
    echo -e "$OK"
else
    echo -e "$FAIL (not found)"
fi

# =============================================================================
# 2. Check PostgreSQL
# =============================================================================
echo -n "PostgreSQL connection... "
if PGPASSWORD=jsroot psql -h 127.0.0.1 -U jumpserver -d jumpserver -c '\q' 2>/dev/null; then
    echo -e "$OK"
else
    echo -e "$FAIL"
fi

# =============================================================================
# 3. Check Redis
# =============================================================================
echo -n "Redis connection... "
if redis-cli ping 2>/dev/null | grep -q "PONG"; then
    echo -e "$OK"
else
    echo -e "$FAIL"
fi

# =============================================================================
# 4. Check certificate directories
# =============================================================================
echo -n "Certificate directories... "
if [ -d "data/certs/mtls" ] && [ -d "data/certs/pki" ]; then
    echo -e "$OK"
else
    echo -e "$FAIL (not found)"
fi

# =============================================================================
# 5. Check CA certificate
# =============================================================================
echo -n "CA certificate (mtls)... "
if [ -f "data/certs/mtls/internal-ca.crt" ]; then
    echo -e "$OK"
else
    echo -e "$FAIL (not found)"
fi

# =============================================================================
# 6. Check CA CRL
# =============================================================================
echo -n "CA CRL (mtls)... "
if [ -f "data/certs/mtls/internal-ca.crl" ]; then
    echo -e "$OK"
else
    echo -e "$FAIL (not found)"
fi

# =============================================================================
# 7. Check server SSL certificate
# =============================================================================
echo -n "Server SSL certificate... "
if [ -f "data/certs/mtls/server.crt" ]; then
    echo -e "$OK"
else
    echo -e "$FAIL (not found)"
fi

# =============================================================================
# 8. Check Django installation
# =============================================================================
echo -n "Django installation... "
if source venv/bin/activate && python -c "import django" 2>/dev/null; then
    echo -e "$OK"
    deactivate 2>/dev/null
else
    echo -e "$FAIL"
fi

# =============================================================================
# 9. Check nginx
# =============================================================================
echo -n "nginx installed... "
if command -v nginx &> /dev/null; then
    echo -e "$OK"
else
    echo -e "$FAIL"
fi

echo -n "nginx running... "
if pgrep nginx > /dev/null 2>&1; then
    echo -e "$OK"
else
    echo -e "$FAIL"
fi

echo -n "nginx config (jumpserver-mtls)... "
if [ -f "/etc/nginx/sites-available/jumpserver-mtls" ]; then
    echo -e "$OK"
else
    echo -e "$FAIL (not found)"
fi

echo -n "nginx config enabled... "
if [ -L "/etc/nginx/sites-enabled/jumpserver-mtls" ]; then
    echo -e "$OK"
else
    echo -e "$FAIL (not enabled)"
fi

echo -n "nginx default site disabled... "
if [ ! -L "/etc/nginx/sites-enabled/default" ]; then
    echo -e "$OK"
else
    echo -e "$WARN (still enabled)"
fi

# =============================================================================
# 10. Check database tables
# =============================================================================
if source venv/bin/activate 2>/dev/null; then
    echo -n "PKI tables... "
    TABLE_COUNT=$(PGPASSWORD=jsroot psql -h 127.0.0.1 -U jumpserver -d jumpserver -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE 'pki_%';" 2>/dev/null | xargs)
    if [ "$TABLE_COUNT" -gt 0 ]; then
        echo -e "$OK ($TABLE_COUNT tables)"
    else
        echo -e "$FAIL (not found)"
    fi

    echo -n "Blockchain tables... "
    TABLE_COUNT=$(PGPASSWORD=jsroot psql -h 127.0.0.1 -U jumpserver -d jumpserver -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE 'blockchain_%';" 2>/dev/null | xargs)
    if [ "$TABLE_COUNT" -gt 0 ]; then
        echo -e "$OK ($TABLE_COUNT tables)"
    else
        echo -e "$FAIL (not found)"
    fi

    # =============================================================================
    # 11. Check CA in database
    # =============================================================================
    echo -n "CA in database... "
    cd apps
    CA_COUNT=$(python manage.py shell -c "from pki.models import CertificateAuthority; print(CertificateAuthority.objects.count())" 2>/dev/null)
    if [ "$CA_COUNT" -gt 0 ]; then
        echo -e "$OK"
    else
        echo -e "$FAIL (not initialized)"
    fi

    # =============================================================================
    # 12. Check users
    # =============================================================================
    echo -n "Users in database... "
    USER_COUNT=$(python manage.py shell -c "from users.models import User; print(User.objects.count())" 2>/dev/null)
    if [ "$USER_COUNT" -gt 0 ]; then
        echo -e "$OK ($USER_COUNT users)"
    else
        echo -e "$WARN (no users)"
    fi

    # =============================================================================
    # 13. Check certificates issued
    # =============================================================================
    echo -n "Certificates issued... "
    CERT_COUNT=$(python manage.py shell -c "from pki.models import Certificate; print(Certificate.objects.count())" 2>/dev/null)
    if [ "$CERT_COUNT" -gt 0 ]; then
        echo -e "$OK ($CERT_COUNT certificates)"
    else
        echo -e "$WARN (no certificates)"
    fi

    # =============================================================================
    # 14. Check blockchain roles
    # =============================================================================
    echo -n "Blockchain roles... "
    ROLE_COUNT=$(python manage.py shell -c "from rbac.models import Role; print(Role.objects.filter(name__icontains='Blockchain').count())" 2>/dev/null)
    if [ "$ROLE_COUNT" -eq 3 ]; then
        echo -e "$OK (3 roles)"
    else
        echo -e "$WARN ($ROLE_COUNT roles, expected 3)"
    fi

    cd ..
    deactivate 2>/dev/null
fi

# =============================================================================
# 15. Check ports
# =============================================================================
echo -n "Port 8080 (Django)... "
if netstat -tln 2>/dev/null | grep -q ":8080" || ss -tln 2>/dev/null | grep -q ":8080"; then
    echo -e "$OK (listening)"
else
    echo -e "$WARN (not listening - Django not running)"
fi

echo -n "Port 443 (nginx HTTPS)... "
if netstat -tln 2>/dev/null | grep -q ":443" || ss -tln 2>/dev/null | grep -q ":443"; then
    echo -e "$OK (listening)"
else
    echo -e "$FAIL (not listening)"
fi

echo -n "Port 80 (nginx HTTP)... "
if netstat -tln 2>/dev/null | grep -q ":80" || ss -tln 2>/dev/null | grep -q ":80"; then
    echo -e "$OK (listening)"
else
    echo -e "$WARN (not listening)"
fi

echo
echo "========================================="
echo "Diagnostic Complete"
echo "========================================="
echo
echo "If you see failures above, run: ./fix_setup.sh"
