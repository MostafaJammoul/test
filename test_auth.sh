#!/bin/bash
# Test if session authentication works after MFA verification

echo "=== Testing Session Authentication ==="
echo ""

# Step 1: Get session cookie during login
echo "1. Login with admin/admin..."
RESPONSE=$(curl -s -c cookies.txt -X POST http://localhost:8080/api/v1/authentication/tokens/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}')

echo "Response: $RESPONSE"
echo ""

# Step 2: Verify MFA (use your current TOTP code)
echo "2. Enter your TOTP code from authenticator app:"
read TOTP_CODE

RESPONSE=$(curl -s -b cookies.txt -c cookies.txt -X POST http://localhost:8080/api/v1/authentication/mfa/verify-totp/ \
  -H "Content-Type: application/json" \
  -d "{\"code\":\"$TOTP_CODE\"}")

echo "MFA Verification Response:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
echo ""

# Extract token from response
TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
    echo "✓ Token received: ${TOKEN:0:20}..."
    echo ""

    # Step 3: Test with session cookie only (no token)
    echo "3. Testing /users/users/ with SESSION COOKIE only (no Bearer token):"
    curl -v -b cookies.txt http://localhost:8080/api/v1/users/users/ 2>&1 | grep -E "(HTTP/|< HTTP|401|200|403|Cookie:|Set-Cookie:)"
    echo ""

    # Step 4: Test with Bearer token only (no session)
    echo "4. Testing /users/users/ with BEARER TOKEN only (no session cookie):"
    curl -v -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/v1/users/users/ 2>&1 | grep -E "(HTTP/|< HTTP|401|200|403|Authorization:)"
    echo ""

    # Step 5: Test with both
    echo "5. Testing /users/users/ with BOTH session cookie AND Bearer token:"
    curl -v -b cookies.txt -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/v1/users/users/ 2>&1 | grep -E "(HTTP/|< HTTP|401|200|403)"
    echo ""
else
    echo "✗ No token received in MFA verification response"
    echo "Full response: $RESPONSE"
fi
