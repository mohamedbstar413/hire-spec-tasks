#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

echo "=================================================="
echo " Verifying Task: Localhost Hosts Misconfiguration"
echo "=================================================="

# 1. Inspect /etc/hosts for localhost resolution
log_info "Inspecting /etc/hosts for localhost mapping..."
if grep -E "100\.100\.100\.100\s+localhost" /etc/hosts >/dev/null 2>&1; then
    log_fail "Check failed: /etc/hosts still maps 'localhost' to '100.100.100.100'."
fi

if ! grep -E "127\.0\.0\.1\s+localhost" /etc/hosts >/dev/null 2>&1; then
    log_fail "Check failed: /etc/hosts does not map 'localhost' to '127.0.0.1'."
fi
log_pass "/etc/hosts maps 'localhost' to '127.0.0.1'."

# 2. Check getent hosts localhost
log_info "Verifying hostname resolution for localhost..."
RESOLVED_IP=$(getent hosts localhost | awk '{print $1}' | head -n 1 || echo "")

if [[ "$RESOLVED_IP" != "127.0.0.1" && "$RESOLVED_IP" != "::1" ]]; then
    log_fail "DNS check failed: 'localhost' resolves to '$RESOLVED_IP' (Expected 127.0.0.1)."
fi
log_pass "'localhost' resolves correctly to 127.0.0.1."

# 3. Test HTTP connectivity to http://localhost:3000
log_info "Testing HTTP connectivity to http://localhost:3000..."
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:3000/ || true)
HTTP_BODY=$(echo "$HTTP_RESPONSE" | head -n 1)
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n 1)

if [[ "$HTTP_STATUS" != "200" ]]; then
    log_fail "HTTP check failed: Request to http://localhost:3000 returned status $HTTP_STATUS (Expected 200)."
fi

if ! echo "$HTTP_BODY" | grep -iq "WebApp Healthy"; then
    log_fail "Body check failed: Response body does not contain expected string 'WebApp Healthy'. Received: '$HTTP_BODY'."
fi

log_pass "Successfully connected to http://localhost:3000 (Status: 200 OK, Body: '$HTTP_BODY')."

echo "=================================================="
echo -e "${GREEN}ALL LOCALHOST HOSTS CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
