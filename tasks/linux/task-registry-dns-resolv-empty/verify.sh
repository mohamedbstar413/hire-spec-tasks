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
echo " Verifying Task: External Connectivity & DNS Fix"
echo "=================================================="

# 1. Check /etc/resolv.conf is non-empty and contains a nameserver
log_info "Inspecting /etc/resolv.conf for nameserver configuration..."
if [[ ! -f /etc/resolv.conf ]]; then
    log_fail "Check failed: /etc/resolv.conf does not exist."
fi

if ! grep -qE "^nameserver[[:space:]]+[0-9a-fA-F:\.]+" /etc/resolv.conf; then
    log_fail "Check failed: /etc/resolv.conf does not contain a valid 'nameserver' directive."
fi
log_pass "/etc/resolv.conf contains an active nameserver entry."

# 2. Test HTTP connectivity to google.com
log_info "Testing HTTP connectivity to https://google.com..."
if ! curl -s --connect-timeout 5 https://google.com >/dev/null 2>&1; then
    log_fail "Connectivity check failed: Unable to connect to https://google.com."
fi
log_pass "Successfully connected to https://google.com."

# 3. Test running /opt/scripts/check_connectivity.sh
if [[ -f /opt/scripts/check_connectivity.sh ]]; then
    log_info "Executing /opt/scripts/check_connectivity.sh..."
    if ! /opt/scripts/check_connectivity.sh >/tmp/check.log 2>&1; then
        log_fail "Connectivity check script failed. Output:\n$(cat /tmp/check.log)"
    fi
    log_pass "/opt/scripts/check_connectivity.sh executed successfully."
fi

echo "=================================================="
echo -e "${GREEN}ALL CONNECTIVITY CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
