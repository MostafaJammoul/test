#!/bin/bash

echo "=========================================="
echo "Certificate Diagnostic Script"
echo "=========================================="
echo ""

# Find the actual project directory
if [ -d ~/js ]; then
    PROJECT_DIR=~/js
elif [ -d /home/jsroot/js ]; then
    PROJECT_DIR=/home/jsroot/js
else
    PROJECT_DIR=$(pwd)
fi

echo "Project Directory: $PROJECT_DIR"
echo ""

echo "=== Directory Structure ==="
ls -la $PROJECT_DIR/data/certs/ 2>/dev/null || echo "data/certs/ does not exist!"
echo ""

echo "=== mtls Directory ==="
ls -la $PROJECT_DIR/data/certs/mtls/ 2>/dev/null || echo "data/certs/mtls/ does not exist!"
echo ""

echo "=== Checking if openssl is available ==="
which openssl || echo "OpenSSL NOT installed!"
openssl version 2>/dev/null || echo "OpenSSL not working"
echo ""

echo "=== Attempting to create certificates manually ==="
mkdir -p $PROJECT_DIR/data/certs/mtls

# Generate server certificate
echo "Generating server certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout $PROJECT_DIR/data/certs/mtls/server.key \
    -out $PROJECT_DIR/data/certs/mtls/server.crt \
    -subj "/C=US/ST=California/L=SanFrancisco/O=JumpServer/CN=localhost" 2>&1

if [ $? -eq 0 ]; then
    echo "✓ Server certificate created successfully"
    chmod 600 $PROJECT_DIR/data/certs/mtls/server.key
    chmod 644 $PROJECT_DIR/data/certs/mtls/server.crt

    echo ""
    echo "=== Verification ==="
    ls -lh $PROJECT_DIR/data/certs/mtls/
    echo ""
    openssl x509 -in $PROJECT_DIR/data/certs/mtls/server.crt -noout -subject -dates
else
    echo "✗ Failed to create server certificate"
fi

echo ""
echo "=== Checking CA export ==="
if [ -f "$PROJECT_DIR/data/certs/mtls/internal-ca.crt" ]; then
    echo "✓ CA certificate exists"
    openssl x509 -in $PROJECT_DIR/data/certs/mtls/internal-ca.crt -noout -subject -dates 2>/dev/null
else
    echo "✗ CA certificate does not exist"
    echo "  Attempting to export from database..."

    cd $PROJECT_DIR/apps
    if [ -f manage.py ]; then
        python manage.py export_ca_cert --output ../data/certs/mtls/internal-ca.crt --force 2>&1

        if [ -f "../data/certs/mtls/internal-ca.crt" ]; then
            echo "✓ CA certificate exported successfully"
        else
            echo "✗ CA export failed"
        fi
    else
        echo "✗ Cannot find manage.py"
    fi
    cd - > /dev/null
fi

echo ""
echo "=== Final Status ==="
ls -lh $PROJECT_DIR/data/certs/mtls/ 2>/dev/null || echo "mtls directory still empty!"

echo ""
echo "=========================================="
