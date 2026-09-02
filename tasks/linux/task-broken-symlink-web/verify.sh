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
echo " Verifying Task: Broken Web Symlink Fix"
echo "=================================================="

# 1. Check if /var/www/html/current is a valid symlink pointing to /var/www/html/v2
log_info "Verifying symbolic link '/var/www/html/current'..."

if [[ ! -L /var/www/html/current ]]; then
    log_fail "Symlink check failed: '/var/www/html/current' is not a symbolic link."
fi

SYMLINK_TARGET=$(readlink -f /var/www/html/current || true)

if [[ "$SYMLINK_TARGET" != "/var/www/html/v2" ]]; then
    log_fail "Symlink check failed: '/var/www/html/current' points to '$SYMLINK_TARGET', expected '/var/www/html/v2'."
fi

log_pass "Symbolic link '/var/www/html/current' correctly points to '/var/www/html/v2'."

# 2. Check HTTP endpoint response from Nginx
log_info "Testing HTTP response from http://localhost/..."
HTTP_CODE=$(curl -s -o /tmp/web_response.html -w "%{http_code}" http://localhost/ || true)

if [[ "$HTTP_CODE" != "200" ]]; then
    log_fail "HTTP check failed: Server returned status code $HTTP_CODE (Expected HTTP 200)."
fi

if ! grep -q "Welcome to App v2" /tmp/web_response.html; then
    log_fail "HTTP content check failed: Response body does not contain expected 'Welcome to App v2' content."
fi

log_pass "Web server successfully returned HTTP 200 OK with App v2 content."

echo "=================================================="
echo -e "${GREEN}ALL BROKEN SYMLINK CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
