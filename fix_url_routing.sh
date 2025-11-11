#!/bin/bash
# Diagnostic and fix script for Django URL routing issue
# Issue: /api/v1/users/me/ returns 404 despite code being present

echo "=== Step 1: Check for multiple runserver processes ==="
ps aux | grep "python manage.py runserver" | grep -v grep
PROCESS_COUNT=$(ps aux | grep "python manage.py runserver" | grep -v grep | wc -l)
echo "Found $PROCESS_COUNT runserver process(es)"

echo ""
echo "=== Step 2: Kill ALL runserver processes ==="
pkill -9 -f "python manage.py runserver"
sleep 2
echo "Verifying all killed..."
ps aux | grep "python manage.py runserver" | grep -v grep || echo "✓ All processes killed"

echo ""
echo "=== Step 3: Clear Django cache and bytecode ==="
cd apps
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
echo "✓ Cache cleared"

echo ""
echo "=== Step 4: Verify Django can see the URL pattern ==="
source ../venv/bin/activate
echo "Checking for 'users/me' URL pattern..."
python manage.py show_urls 2>/dev/null | grep -i "me" || echo "Note: show_urls command may not be available"

echo ""
echo "=== Step 5: Check URL configuration directly ==="
python manage.py shell <<'PYEOF'
from django.urls import get_resolver
from django.conf import settings

print("\n=== Checking URL patterns in users app ===")
try:
    resolver = get_resolver()
    # Get all URL patterns
    patterns = resolver.url_patterns

    found = False
    for pattern in patterns:
        pattern_str = str(pattern.pattern)
        if 'api' in pattern_str:
            print(f"Found API pattern: {pattern_str}")
            # Check if it's the users API
            if hasattr(pattern, 'url_patterns'):
                for sub in pattern.url_patterns:
                    sub_str = str(sub.pattern)
                    if 'users' in sub_str or 'me' in sub_str:
                        print(f"  - {sub_str}")
                        found = True

    if not found:
        print("⚠ Could not find users/me pattern in URL resolver")
    else:
        print("✓ URL patterns loaded successfully")

except Exception as e:
    print(f"Error checking URLs: {e}")

print("\n=== Checking if api_urls.py is imported ===")
try:
    from users.urls import api_urls
    print(f"✓ users.urls.api_urls module imported successfully")
    print(f"  urlpatterns count: {len(api_urls.urlpatterns)}")
    for pattern in api_urls.urlpatterns:
        pattern_str = str(pattern.pattern)
        if 'me' in pattern_str or 'profile' in pattern_str:
            print(f"  - Found: {pattern_str}")
except Exception as e:
    print(f"✗ Error importing api_urls: {e}")
PYEOF

echo ""
echo "=== Step 6: Start backend with fresh process ==="
cd ..
nohup python apps/manage.py runserver 0.0.0.0:8080 > data/logs/backend.log 2>&1 &
BACKEND_PID=$!
echo "Backend started with PID: $BACKEND_PID"
echo "Waiting 5 seconds for server to start..."
sleep 5

echo ""
echo "=== Step 7: Test endpoint directly ==="
echo "Testing: http://localhost:8080/api/v1/users/me/"
curl -v http://localhost:8080/api/v1/users/me/ 2>&1 | grep -E "(HTTP|< HTTP|error|Error|404|200)"

echo ""
echo "=== Step 8: Check recent backend logs ==="
echo "Last 20 lines of backend log:"
tail -20 data/logs/backend.log

echo ""
echo "=== Step 9: Test with authentication ==="
echo "Testing with admin credentials..."
# Get auth token
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/authentication/tokens/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}')
echo "Token response: $TOKEN_RESPONSE"

if echo "$TOKEN_RESPONSE" | grep -q "token"; then
  TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
  echo "Testing /api/v1/users/me/ with token..."
  curl -v http://localhost:8080/api/v1/users/me/ \
    -H "Authorization: Bearer $TOKEN" 2>&1 | grep -E "(HTTP|< HTTP|200|404|username|role)"
else
  echo "⚠ Could not get auth token, password may need reset"
fi

echo ""
echo "=== Diagnosis Complete ==="
echo "The URL pattern was fixed from 'users/me/' to 'me/'"
echo "This prevents double 'users' in the path: /api/v1/users/me/"
