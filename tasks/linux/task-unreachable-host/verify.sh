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
echo " Verifying Task: Network Troubleshooting Chain"
echo "=================================================="

# 1. Verify HTTP accessibility to crm.internal
log_info "Testing HTTP connectivity to crm.internal..."
if ! curl -m 5 -sf http://crm.internal/ >/dev/null 2>&1; then
    if ! curl -m 5 -sf http://10.5.0.20/ >/dev/null 2>&1; then
        log_fail "HTTP request to crm.internal (10.5.0.20) failed or timed out."
    fi
fi
log_pass "HTTP connectivity to crm.internal is functional."

# 2. Check iptables rules on crm.internal
log_info "Checking active firewall configuration..."
if docker exec crm.internal iptables -L INPUT -n 2>/dev/null | grep -qE "dpt:80.*DROP"; then
    log_fail "Firewall check failed: crm.internal active iptables still contains a DROP rule for port 80."
fi
log_pass "No blocking DROP rules found in active firewall."

# 3. Check persistence file /etc/iptables/rules.v4
log_info "Verifying persistence file /etc/iptables/rules.v4..."
if docker exec crm.internal test -f /etc/iptables/rules.v4 2>/dev/null; then
    if docker exec crm.internal grep -qE "dpt:80.*DROP|-A INPUT.*--dport 80.*DROP" /etc/iptables/rules.v4; then
        log_fail "Persistence check failed: /etc/iptables/rules.v4 on crm.internal still contains the DROP rule for port 80."
    fi
fi
log_pass "Firewall persistence file verified cleanly."

echo "=================================================="
echo -e "${GREEN}ALL NETWORK TROUBLESHOOTING CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
