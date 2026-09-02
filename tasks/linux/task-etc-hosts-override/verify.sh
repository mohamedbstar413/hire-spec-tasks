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
echo " Verifying Task: /etc/hosts Static Override Fix"
echo "=================================================="

# 1. Execute /opt/hostcheck/check.sh and verify output is 200
log_info "Executing /opt/hostcheck/check.sh..."
CHECK_OUTPUT=$(/opt/hostcheck/check.sh 2>&1 || true)
CHECK_OUTPUT_TRIMMED=$(echo "$CHECK_OUTPUT" | tr -d '\r\n')

if [[ "$CHECK_OUTPUT_TRIMMED" != "200" ]]; then
    log_fail "Health check failed: /opt/hostcheck/check.sh returned '$CHECK_OUTPUT_TRIMMED' (Expected 200)."
fi

log_pass "/opt/hostcheck/check.sh successfully returned HTTP 200."

# 2. Verify stale IP 203.0.113.50 is no longer mapped in /etc/hosts
log_info "Verifying /etc/hosts file entries..."
if grep -q "203.0.113.50" /etc/hosts 2>/dev/null; then
    log_fail "Hosts file check failed: Stale IP '203.0.113.50' is still present in /etc/hosts."
fi

log_pass "Stale IP '203.0.113.50' removed from /etc/hosts."

# 3. Verify resolution of internal-api.company.local
log_info "Testing hostname resolution for internal-api.company.local..."
RESOLVED_IP=$(getent hosts internal-api.company.local | awk '{print $1}' || true)

if [[ "$RESOLVED_IP" != "127.0.0.1" && "$RESOLVED_IP" != "::1" && "$RESOLVED_IP" != "localhost" ]]; then
    log_fail "Resolution check failed: 'internal-api.company.local' resolves to '$RESOLVED_IP', expected 127.0.0.1."
fi

log_pass "'internal-api.company.local' correctly resolves to 127.0.0.1."

echo "=================================================="
echo -e "${GREEN}ALL /etc/hosts OVERRIDE CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
