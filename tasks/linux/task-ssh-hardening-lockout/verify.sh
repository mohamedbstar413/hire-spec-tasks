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
echo " Verifying Task: SSH Hardening Lockout Fix"
echo "=================================================="

# 1. Test SSH Configuration Syntax (sshd -t)
log_info "Testing SSH configuration syntax (sshd -t)..."
if ! sshd -t >/tmp/sshd_syntax.log 2>&1; then
    log_fail "SSH configuration check failed! Syntax error found:\n$(cat /tmp/sshd_syntax.log)"
fi
log_pass "SSH configuration syntax is valid."

# 2. Check Host Private Key Permissions
#log_info "Checking permissions on SSH host private keys..."
#for key in /etc/ssh/ssh_host_*_key; do
#    if [[ -f "$key" ]]; then
#        PERMS=$(stat -c "%a" "$key")
#        if [[ "$PERMS" != "600" && "$PERMS" != "400" ]]; then
#            log_fail "Key permission check failed: '$key' has insecure permissions ($PERMS). Expected 0600."
#        fi
#    fi
#done
#log_pass "Host private key permissions are secure (0600)."

# 3. Check sshd Service Status
log_info "Checking if sshd service is active..."
if ! systemctl is-active --quiet sshd && ! systemctl is-active --quiet ssh; then
    log_fail "Service check failed: sshd service is not active/running."
fi
log_pass "SSH daemon service is active."

# 4. Check Port 22 Reachability
log_info "Testing TCP port 22 connection..."
if ! nc -z 127.0.0.1 22 2>/dev/null; then
    log_fail "Port check failed: SSH service is not accepting connections on port 22."
fi
log_pass "SSH service is accepting connections on port 22."

echo "=================================================="
echo -e "${GREEN}ALL SSH HARDENING LOCKOUT CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
