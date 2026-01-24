#!/bin/bash
# Test the login endpoint directly to see the exact error

echo "=========================================="
echo "Testing Login Endpoint"
echo "=========================================="
echo ""

echo "1. Testing with curl (verbose)..."
echo ""

curl -v -X POST http://localhost:8080/api/v1/authentication/tokens/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' \
  2>&1 | tee /tmp/login_test.log

echo ""
echo ""
echo "2. Testing with different content type..."
curl -v -X POST http://localhost:8080/api/v1/authentication/tokens/ \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=admin" \
  2>&1

echo ""
echo ""
echo "3. Checking Django logs for this request..."
tail -50 ~/js/data/logs/jumpserver.log 2>/dev/null || echo "No log file found"

echo ""
echo "=========================================="
