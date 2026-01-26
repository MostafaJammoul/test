#!/bin/bash
# Test mTLS Connection to API Bridge
#
# This script tests the mTLS connection between JumpServer (VM 1) and
# the API bridge (VM 2) after certificates have been generated.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/certs"
CLIENT_CERTS_DIR="$SCRIPT_DIR/client-certs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "========================================"
echo "mTLS Connection Test"
echo "========================================"
echo ""

# Check if certificates exist
if [ ! -f "$CERTS_DIR/ca-cert.pem" ]; then
    echo -e "${RED}✗ Certificates not found!${NC}"
    echo ""
    echo "Please run setup-mtls.sh first to generate certificates:"
    echo "  ${GREEN}./setup-mtls.sh${NC}"
    echo ""
    exit 1
fi

echo -e "${BLUE}Found certificates in $CERTS_DIR${NC}"
echo ""

# Determine API URL
API_URL="${1:-https://localhost:3001}"
echo -e "${BLUE}Testing connection to: $API_URL${NC}"
echo ""

# ============================================================================
# Test 1: Server reachability (without mTLS)
# ============================================================================

echo -e "${BLUE}Test 1: Server Reachability${NC}"
echo "-------------------------------------------"

if curl -s --connect-timeout 5 --cacert "$CERTS_DIR/ca-cert.pem" "$API_URL/api/health" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Warning: Server accepted connection without client certificate!${NC}"
    echo "  This indicates mTLS is not properly enabled."
    echo "  The server should reject connections without a client certificate."
    echo ""
else
    echo -e "${GREEN}✓ Server correctly rejected connection without client certificate${NC}"
    echo ""
fi

# ============================================================================
# Test 2: mTLS Health Check (with client certificate)
# ============================================================================

echo -e "${BLUE}Test 2: mTLS Health Check${NC}"
echo "-------------------------------------------"

HEALTH_RESPONSE=$(curl -s \
    --cert "$CLIENT_CERTS_DIR/jumpserver-client-cert.pem" \
    --key "$CLIENT_CERTS_DIR/jumpserver-client-key.pem" \
    --cacert "$CLIENT_CERTS_DIR/ca-cert.pem" \
    "$API_URL/api/health" 2>&1)

if echo "$HEALTH_RESPONSE" | grep -q "status"; then
    echo -e "${GREEN}✓ mTLS connection successful${NC}"
    echo ""
    echo "Response:"
    echo "$HEALTH_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$HEALTH_RESPONSE"
    echo ""
else
    echo -e "${RED}✗ mTLS connection failed${NC}"
    echo ""
    echo "Error response:"
    echo "$HEALTH_RESPONSE"
    echo ""
    exit 1
fi

# ============================================================================
# Test 3: Verify Certificate Details
# ============================================================================

echo -e "${BLUE}Test 3: Certificate Verification${NC}"
echo "-------------------------------------------"

echo ""
echo -e "${YELLOW}Client Certificate (JumpServer):${NC}"
openssl x509 -in "$CLIENT_CERTS_DIR/jumpserver-client-cert.pem" -noout -subject -issuer -dates | sed 's/^/  /'

echo ""
echo -e "${YELLOW}Server Certificate (API Bridge):${NC}"
echo "  Testing TLS handshake..."

# Extract server certificate and verify
SERVER_CERT_INFO=$(echo | openssl s_client \
    -connect ${API_URL#https://} \
    -cert "$CLIENT_CERTS_DIR/jumpserver-client-cert.pem" \
    -key "$CLIENT_CERTS_DIR/jumpserver-client-key.pem" \
    -CAfile "$CLIENT_CERTS_DIR/ca-cert.pem" \
    2>&1 | grep -A 5 "Certificate chain")

if [ -n "$SERVER_CERT_INFO" ]; then
    echo -e "${GREEN}✓ TLS handshake successful${NC}"
else
    echo -e "${YELLOW}⚠ Unable to verify server certificate details${NC}"
fi

echo ""

# ============================================================================
# Test 4: API Endpoints (if server is fully operational)
# ============================================================================

echo -e "${BLUE}Test 4: API Endpoint Tests${NC}"
echo "-------------------------------------------"

# Test evidence query (should return empty or error for non-existent evidence)
echo ""
echo "Testing GET /api/evidence/test-evidence-id..."

QUERY_RESPONSE=$(curl -s \
    --cert "$CLIENT_CERTS_DIR/jumpserver-client-cert.pem" \
    --key "$CLIENT_CERTS_DIR/jumpserver-client-key.pem" \
    --cacert "$CLIENT_CERTS_DIR/ca-cert.pem" \
    "$API_URL/api/evidence/test-evidence-id" 2>&1)

if echo "$QUERY_RESPONSE" | grep -q "error\|message"; then
    echo -e "${GREEN}✓ API endpoint responding (returned expected error for non-existent evidence)${NC}"
else
    echo -e "${YELLOW}⚠ Unexpected response from API endpoint${NC}"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "========================================"
echo -e "${GREEN}✓ mTLS Connection Tests Complete!${NC}"
echo "========================================"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Copy client certificates to VM 1 (JumpServer):"
echo "   ${GREEN}scp -r $CLIENT_CERTS_DIR user@VM1_IP:/home/user/test/certs/${NC}"
echo ""
echo "2. Update JumpServer config.yml:"
echo "   FABRIC_API_URL: \"$API_URL\""
echo "   FABRIC_CLIENT_CERT: \"/home/user/test/certs/jumpserver-client-cert.pem\""
echo "   FABRIC_CLIENT_KEY: \"/home/user/test/certs/jumpserver-client-key.pem\""
echo "   FABRIC_CA_CERT: \"/home/user/test/certs/ca-cert.pem\""
echo ""
echo "3. Test from JumpServer (VM 1):"
echo "   ${GREEN}curl --cert /home/user/test/certs/jumpserver-client-cert.pem \\\\${NC}"
echo "   ${GREEN}        --key /home/user/test/certs/jumpserver-client-key.pem \\\\${NC}"
echo "   ${GREEN}        --cacert /home/user/test/certs/ca-cert.pem \\\\${NC}"
echo "   ${GREEN}        $API_URL/api/health${NC}"
echo ""
echo "========================================"
echo ""
