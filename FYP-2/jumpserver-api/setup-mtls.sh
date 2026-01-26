#!/bin/bash
# Generate mTLS Certificates for JumpServer-Fabric API Bridge
#
# This script generates:
# 1. CA certificate (Certificate Authority)
# 2. Server certificate for API bridge (VM 2)
# 3. Client certificate for Django JumpServer (VM 1)

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
echo "mTLS Certificate Generation"
echo "========================================"
echo ""

# Create directories
mkdir -p "$CERTS_DIR"
mkdir -p "$CLIENT_CERTS_DIR"

cd "$CERTS_DIR"

# Check if certificates already exist
if [ -f "ca-cert.pem" ] && [ -f "server-cert.pem" ] && [ -f "jumpserver-client-cert.pem" ]; then
    echo -e "${YELLOW}⚠ Certificates already exist!${NC}"
    echo ""
    read -p "Do you want to regenerate them? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}ℹ Using existing certificates${NC}"
        exit 0
    fi
    echo -e "${YELLOW}Backing up existing certificates...${NC}"
    mv ca-cert.pem ca-cert.pem.bak 2>/dev/null || true
    mv server-cert.pem server-cert.pem.bak 2>/dev/null || true
    mv jumpserver-client-cert.pem jumpserver-client-cert.pem.bak 2>/dev/null || true
fi

echo -e "${BLUE}Step 1: Generating Certificate Authority (CA)${NC}"
echo "-------------------------------------------"

# Generate CA private key (4096-bit RSA)
openssl genrsa -out ca-key.pem 4096 2>/dev/null

# Generate CA certificate (valid for 10 years)
openssl req -new -x509 -days 3650 -key ca-key.pem -out ca-cert.pem \
    -subj "/C=US/ST=State/L=City/O=JumpServer-FYP2/OU=Security/CN=FYP2-RootCA" \
    2>/dev/null

echo -e "${GREEN}✓ CA certificate generated${NC}"
echo "  - CA Private Key: ca-key.pem"
echo "  - CA Certificate: ca-cert.pem"
echo ""

# ============================================================================
# Server Certificate (API Bridge on VM 2)
# ============================================================================

echo -e "${BLUE}Step 2: Generating Server Certificate (API Bridge)${NC}"
echo "-------------------------------------------"

# Generate server private key
openssl genrsa -out server-key.pem 4096 2>/dev/null

# Generate server CSR (Certificate Signing Request)
openssl req -new -key server-key.pem -out server.csr \
    -subj "/C=US/ST=State/L=City/O=JumpServer-FYP2/OU=API-Bridge/CN=fyp2-api-bridge" \
    2>/dev/null

# Create server certificate extensions file
cat > server-ext.cnf <<EOF
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "API Bridge Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = fyp2-api-bridge
DNS.3 = *.local
IP.1 = 127.0.0.1
IP.2 = 192.168.0.0/16
IP.3 = 10.0.0.0/8
EOF

# Sign server certificate with CA
openssl x509 -req -in server.csr -CA ca-cert.pem -CAkey ca-key.pem \
    -CAcreateserial -out server-cert.pem -days 3650 \
    -extfile server-ext.cnf \
    2>/dev/null

echo -e "${GREEN}✓ Server certificate generated${NC}"
echo "  - Server Private Key: server-key.pem"
echo "  - Server Certificate: server-cert.pem"
echo ""

# ============================================================================
# Client Certificate (Django JumpServer on VM 1)
# ============================================================================

echo -e "${BLUE}Step 3: Generating Client Certificate (Django JumpServer)${NC}"
echo "-------------------------------------------"

# Generate client private key
openssl genrsa -out jumpserver-client-key.pem 4096 2>/dev/null

# Generate client CSR
openssl req -new -key jumpserver-client-key.pem -out jumpserver-client.csr \
    -subj "/C=US/ST=State/L=City/O=JumpServer-FYP2/OU=JumpServer/CN=jumpserver" \
    2>/dev/null

# Create client certificate extensions file
cat > client-ext.cnf <<EOF
basicConstraints = CA:FALSE
nsCertType = client
nsComment = "JumpServer Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF

# Sign client certificate with CA
openssl x509 -req -in jumpserver-client.csr -CA ca-cert.pem -CAkey ca-key.pem \
    -CAcreateserial -out jumpserver-client-cert.pem -days 3650 \
    -extfile client-ext.cnf \
    2>/dev/null

echo -e "${GREEN}✓ Client certificate generated${NC}"
echo "  - Client Private Key: jumpserver-client-key.pem"
echo "  - Client Certificate: jumpserver-client-cert.pem"
echo ""

# ============================================================================
# Copy client certificates to separate directory for VM 1
# ============================================================================

echo -e "${BLUE}Step 4: Preparing certificates for VM 1 (JumpServer)${NC}"
echo "-------------------------------------------"

cp jumpserver-client-cert.pem "$CLIENT_CERTS_DIR/"
cp jumpserver-client-key.pem "$CLIENT_CERTS_DIR/"
cp ca-cert.pem "$CLIENT_CERTS_DIR/"

echo -e "${GREEN}✓ Client certificates copied to: $CLIENT_CERTS_DIR${NC}"
echo ""

# ============================================================================
# Set proper permissions
# ============================================================================

echo -e "${BLUE}Step 5: Setting file permissions${NC}"
echo "-------------------------------------------"

chmod 600 ca-key.pem
chmod 644 ca-cert.pem
chmod 600 server-key.pem
chmod 644 server-cert.pem
chmod 600 jumpserver-client-key.pem
chmod 644 jumpserver-client-cert.pem
chmod 600 "$CLIENT_CERTS_DIR/jumpserver-client-key.pem"
chmod 644 "$CLIENT_CERTS_DIR/jumpserver-client-cert.pem"
chmod 644 "$CLIENT_CERTS_DIR/ca-cert.pem"

echo -e "${GREEN}✓ Permissions set${NC}"
echo ""

# ============================================================================
# Verify certificates
# ============================================================================

echo -e "${BLUE}Step 6: Verifying certificates${NC}"
echo "-------------------------------------------"

# Verify server certificate
if openssl verify -CAfile ca-cert.pem server-cert.pem > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Server certificate valid${NC}"
else
    echo -e "${RED}✗ Server certificate verification failed${NC}"
    exit 1
fi

# Verify client certificate
if openssl verify -CAfile ca-cert.pem jumpserver-client-cert.pem > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Client certificate valid${NC}"
else
    echo -e "${RED}✗ Client certificate verification failed${NC}"
    exit 1
fi

echo ""

# ============================================================================
# Display certificate information
# ============================================================================

echo -e "${BLUE}Certificate Information:${NC}"
echo "-------------------------------------------"

echo ""
echo -e "${YELLOW}CA Certificate:${NC}"
openssl x509 -in ca-cert.pem -noout -subject -issuer -dates | sed 's/^/  /'

echo ""
echo -e "${YELLOW}Server Certificate:${NC}"
openssl x509 -in server-cert.pem -noout -subject -issuer -dates | sed 's/^/  /'

echo ""
echo -e "${YELLOW}Client Certificate:${NC}"
openssl x509 -in jumpserver-client-cert.pem -noout -subject -issuer -dates | sed 's/^/  /'

echo ""

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "========================================"
echo -e "${GREEN}✓ mTLS Certificates Generated Successfully!${NC}"
echo "========================================"
echo ""

echo -e "${YELLOW}VM 2 (Blockchain) - API Bridge Server:${NC}"
echo "  Location: $CERTS_DIR"
echo "  Files needed:"
echo "    - server-key.pem"
echo "    - server-cert.pem"
echo "    - ca-cert.pem"
echo ""

echo -e "${YELLOW}VM 1 (JumpServer) - Django Client:${NC}"
echo "  Location: $CLIENT_CERTS_DIR"
echo "  Files needed:"
echo "    - jumpserver-client-cert.pem"
echo "    - jumpserver-client-key.pem"
echo "    - ca-cert.pem"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo "1. On VM 2 (Blockchain):"
echo "   - Update .env file with certificate paths"
echo "   - Restart API bridge: ./start.sh"
echo ""
echo "2. Copy client certificates to VM 1:"
echo "   ${GREEN}scp -r $CLIENT_CERTS_DIR user@VM1_IP:/home/user/test/certs/${NC}"
echo ""
echo "3. On VM 1 (JumpServer):"
echo "   - Update config.yml with certificate paths"
echo "   - Restart Django server"
echo ""
echo "4. Test mTLS connection:"
echo "   ${GREEN}curl --cert client-certs/jumpserver-client-cert.pem \\${NC}"
echo "   ${GREEN}     --key client-certs/jumpserver-client-key.pem \\${NC}"
echo "   ${GREEN}     --cacert client-certs/ca-cert.pem \\${NC}"
echo "   ${GREEN}     https://VM2_IP:3001/api/health${NC}"
echo ""

# Clean up temporary files
rm -f server.csr server-ext.cnf jumpserver-client.csr client-ext.cnf ca-cert.srl

echo "========================================"
