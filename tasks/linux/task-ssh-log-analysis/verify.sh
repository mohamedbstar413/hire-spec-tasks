#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

ATTACKER_IP="192.168.1.105"
NORMAL_IP="10.0.2.50"

echo "=================================================="
echo " Verifying Task: SSH Log Analysis & IP Blocking"
echo "=================================================="

# 1. Verify offending IP is blocked in active iptables
log_info "Checking active iptables rules for blocked attacker IP ($ATTACKER_IP)..."
if ! iptables -L INPUT -n 2>/dev/null | grep -q "$ATTACKER_IP"; then
    log_fail "Firewall check failed: Attacker IP '$ATTACKER_IP' is not blocked in iptables."
fi
log_pass "Attacker IP '$ATTACKER_IP' is blocked in active iptables rules."

# 2. Verify non-offending IP is NOT blocked (prevent wildcard/over-blocking)
log_info "Checking that normal IP ($NORMAL_IP) is not blocked..."
if iptables -L INPUT -n 2>/dev/null | grep -q "$NORMAL_IP"; then
    log_fail "Firewall check failed: Normal user IP '$NORMAL_IP' was incorrectly blocked."
fi
log_pass "Normal user IP '$NORMAL_IP' is clean."

# 3. Verify firewall rule persistence
log_info "Verifying persistent firewall configuration in /etc/iptables/rules.v4..."
if [[ -f /etc/iptables/rules.v4 ]]; then
    if ! grep -q "$ATTACKER_IP" /etc/iptables/rules.v4; then
        log_fail "Persistence check failed: /etc/iptables/rules.v4 does not contain the rule for '$ATTACKER_IP'."
    fi
else
    log_fail "Persistence check failed: /etc/iptables/rules.v4 file does not exist."
fi
log_pass "Firewall persistence file verified cleanly."

echo "=================================================="
echo -e "${GREEN}ALL SSH LOG ANALYSIS CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
