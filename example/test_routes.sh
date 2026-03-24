#!/bin/bash
# Sparky 2.1.0 — Test all example routes
# Usage:
#   1. dart run example/sparky_example.dart
#   2. ./example/test_routes.sh

BASE="http://127.0.0.1:3000"

sep() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ─────────────────────────────────────────────────────────────────────
sep "1. Simple route — GET /hello"
curl -s "$BASE/hello"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "2. Dynamic routes — GET /users/42"
curl -s "$BASE/users/42"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "3. JSON serialization — GET /data"
curl -s "$BASE/data"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "4. Body parsing — POST /echo"
curl -s -X POST "$BASE/echo" \
  -H "Content-Type: application/json" \
  -d '{"hello":"world","num":42}'
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "5a. Validation — POST /register (valid)"
curl -s -X POST "$BASE/register" \
  -H "Content-Type: application/json" \
  -d '{"name":"Vinicius","email":"vini@test.com","age":25}'
echo ""

sep "5b. Validation — POST /register (invalid)"
curl -s -X POST "$BASE/register" \
  -H "Content-Type: application/json" \
  -d '{"name":"Vi","email":"not-an-email","age":10}'
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "6. Custom headers — GET /download (show headers)"
curl -s -i "$BASE/download" | head -15
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "7. JWT login — POST /login (get token for next steps)"
LOGIN_RESP=$(curl -s -X POST "$BASE/login" \
  -H "Content-Type: application/json" \
  -d '{"user":"admin"}')
echo "$LOGIN_RESP"
TOKEN=$(echo "$LOGIN_RESP" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "8a. Guard — GET /admin (without token = 401)"
curl -s "$BASE/admin"
echo ""

sep "8b. Guard — GET /admin (with token = 200)"
curl -s "$BASE/admin" -H "Authorization: $TOKEN"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "9a. Route group — GET /api/v1/status (with token)"
curl -s "$BASE/api/v1/status" -H "Authorization: $TOKEN"
echo ""

sep "9b. Route group — GET /api/v1/items (with token)"
curl -s "$BASE/api/v1/items" -H "Authorization: $TOKEN"
echo ""

sep "9c. Route group — GET /api/v1/status (without token = 401)"
curl -s "$BASE/api/v1/status"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "10. Class-based route — GET /test"
curl -s "$BASE/test"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "11. WebSocket — /ws"
echo "(WebSocket requires wscat: wscat -c ws://127.0.0.1:3000/ws)"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "12a. Content negotiation — Accept: application/json"
curl -s "$BASE/negotiate" -H "Accept: application/json"
echo ""

sep "12b. Content negotiation — Accept: text/html"
curl -s "$BASE/negotiate" -H "Accept: text/html"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "13a. Cookies — GET /set-cookie (show Set-Cookie header)"
curl -s -i "$BASE/set-cookie" | grep -iE "set-cookie|^\{"
echo ""

sep "13b. Cookies — GET /read-cookie (send cookie)"
curl -s "$BASE/read-cookie" -b "session=abc123"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "14a. CORS — preflight OPTIONS /hello (allowed origin)"
curl -s -i -X OPTIONS "$BASE/hello" \
  -H "Origin: https://myapp.com" | grep -iE "access-control|vary|HTTP/"
echo ""

sep "14b. CORS — GET /hello (allowed origin)"
curl -s -i "$BASE/hello" \
  -H "Origin: https://myapp.com" | grep -iE "access-control|vary|HTTP/"
echo ""

sep "14c. CORS — GET /hello (disallowed origin)"
curl -s -i "$BASE/hello" \
  -H "Origin: https://evil.com" | grep -iE "access-control-allow-origin|HTTP/"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "15. Rate limiting — send requests until 429"
for i in $(seq 1 105); do
  RESP=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/hello")
  if [ "$RESP" != "200" ]; then
    echo "Request #$i: HTTP $RESP (rate limited)"
    curl -s "$BASE/hello"
    echo ""
    break
  fi
  if [ "$i" = "105" ]; then
    echo "All 105 requests returned 200 (limit not hit)"
  fi
done
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "16. 404 — GET /nonexistent"
curl -s "$BASE/nonexistent"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "17. 405 — POST /hello (only GET allowed)"
curl -s -X POST "$BASE/hello"
echo ""

echo ""
echo "Done!"
