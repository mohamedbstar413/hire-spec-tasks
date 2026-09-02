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
echo " Verifying Task: App Upload ACL Permission Fix"
echo "=================================================="

# 1. Test if appuser can write a test file to /var/www/uploads
log_info "Testing write access to /var/www/uploads as user 'appuser'..."
TEST_FILE="/var/www/uploads/verify_test_$(date +%s).txt"

if ! sudo -u appuser touch "$TEST_FILE" 2>/tmp/acl_write_error.log; then
    log_fail "Write test failed for 'appuser'! Error output:\n$(cat /tmp/acl_write_error.log)"
fi
rm -f "$TEST_FILE"
log_pass "User 'appuser' can successfully write files to /var/www/uploads."

# 2. Check getfacl effective permissions
log_info "Verifying ACL mask and effective permissions via getfacl..."
ACL_OUTPUT=$(getfacl -p /var/www/uploads 2>&1)

if echo "$ACL_OUTPUT" | grep -E "mask::.*r-x" >/dev/null; then
    log_fail "ACL check failed: Restrictive ACL mask 'm::r-x' is still present on /var/www/uploads."
fi

if echo "$ACL_OUTPUT" | grep -E "user:appuser:r-x" >/dev/null; then
    log_fail "ACL check failed: Restrictive user entry 'user:appuser:r-x' is still present on /var/www/uploads."
fi

log_pass "ACL permissions verified: No restrictive masks or entries blocking appuser."

echo "=================================================="
echo -e "${GREEN}ALL ACL PERMISSION CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
