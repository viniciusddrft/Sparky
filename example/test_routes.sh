#!/bin/bash
# Sparky — Test all example routes
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
sep "15a. CSRF — GET /csrf-demo (sets sparky_csrf cookie)"
CSRF_HEADERS=$(curl -s -i -c /tmp/sparky_csrf_cookies "$BASE/csrf-demo")
echo "$CSRF_HEADERS" | grep -iE "^HTTP/|set-cookie|sparky_csrf" | head -5
CSRF_TOKEN=$(grep sparky_csrf /tmp/sparky_csrf_cookies 2>/dev/null | awk '{print $NF}')
echo "token=$CSRF_TOKEN"
echo ""

sep "15b. CSRF — POST /csrf-demo without token (expect 403)"
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST "$BASE/csrf-demo" \
  -H "Content-Type: application/json" \
  -d '{"foo":"bar"}'
echo ""

sep "15c. CSRF — POST /csrf-demo with header + cookie (expect 200)"
curl -s -X POST "$BASE/csrf-demo" \
  -b /tmp/sparky_csrf_cookies \
  -H "Content-Type: application/json" \
  -H "X-CSRF-Token: $CSRF_TOKEN" \
  -d '{"foo":"bar"}'
echo ""
rm -f /tmp/sparky_csrf_cookies

# ─────────────────────────────────────────────────────────────────────
sep "16a. OpenAPI — GET /openapi.json (truncated)"
curl -s "$BASE/openapi.json" | head -c 400
echo "..."
echo ""

sep "16b. OpenAPI — GET /docs (Swagger UI, HTML)"
curl -s -o /dev/null -w "HTTP %{http_code}  content-type=%{content_type}\n" "$BASE/docs"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "17a. Health — GET /health (liveness)"
curl -s "$BASE/health"
echo ""

sep "17b. Health — GET /ready (readiness with checks)"
curl -s "$BASE/ready"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "18. Metrics — GET /metrics (Prometheus exposition)"
curl -s "$BASE/metrics" | grep -E "^# (HELP|TYPE)|_total|_duration_seconds_bucket" | head -20
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "19. Rate limiting — send requests until 429"
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
sep "20. 404 — GET /nonexistent"
curl -s "$BASE/nonexistent"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "21. 405 — POST /hello (only GET allowed)"
curl -s -X POST "$BASE/hello"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "22. Multipart upload — POST /upload"
curl -s -X POST "$BASE/upload" \
  -F "description=My avatar" \
  -F "avatar=@/dev/null;filename=photo.png;type=image/png"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "23. SSE — GET /events (first 5 events, 3s timeout)"
curl -s -N --max-time 3 "$BASE/events" 2>/dev/null || true
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "24a. Structured errors — GET /items/42 (200 OK)"
curl -s "$BASE/items/42"
echo ""

sep "24b. Structured errors — GET /items/0 (404 NotFound)"
curl -s "$BASE/items/0"
echo ""

sep "24c. Structured errors — GET /items/-1 (403 Forbidden)"
curl -s "$BASE/items/-1"
echo ""

sep "24d. Structured errors — GET /items/x (400 BadRequest)"
curl -s "$BASE/items/x"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "25a. Dependency injection — GET /profile (without token = 401)"
curl -s "$BASE/profile"
echo ""

sep "25b. Dependency injection — GET /profile (with token = injected user)"
curl -s "$BASE/profile" -H "Authorization: $TOKEN"
echo ""

# ─────────────────────────────────────────────────────────────────────
sep "26. Security headers — check headers on GET /hello"
curl -s -i "$BASE/hello" | grep -iE "x-frame-options|content-security-policy|referrer-policy|x-content-type-options|strict-transport|x-xss-protection|cross-origin"
echo ""

echo ""
echo "Done!"
