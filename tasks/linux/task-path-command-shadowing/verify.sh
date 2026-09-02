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
echo " Verifying Task: Command Shadowing & PATH Precedence"
echo "=================================================="

# 1. Test command resolution in login bash shell
log_info "Testing 'which ls' in interactive login bash shell..."
RESOLVED_LS=$(bash -l -c "which ls 2>/dev/null" || true)

if [[ "$RESOLVED_LS" == "/root/scripts/ls" ]]; then
    log_fail "PATH check failed: 'ls' is still resolving to fake script '/root/scripts/ls'."
fi

if [[ "$RESOLVED_LS" != "/bin/ls" && "$RESOLVED_LS" != "/usr/bin/ls" ]]; then
    log_fail "PATH check failed: 'ls' resolved to unexpected path: '$RESOLVED_LS'. Expected '/bin/ls' or '/usr/bin/ls'."
fi
log_pass "'ls' correctly resolves to system binary: $RESOLVED_LS"

# 2. Test output of running 'ls /root'
log_info "Testing execution of 'ls /root'..."
LS_OUTPUT=$(bash -l -c "ls /root 2>&1" || true)

if echo "$LS_OUTPUT" | grep -q "0x8849"; then
    log_fail "Execution check failed: 'ls' is still printing the fake error message."
fi

log_pass "'ls' successfully lists directory contents without errors."

# 3. Check /root/.bashrc and /root/.profile for shadowing PATH entries
log_info "Checking /root/.bashrc and /root/.profile PATH definitions..."
if grep -E 'export PATH=.*(/root/scripts|\$HOME/scripts).*:' /root/.bashrc /root/.profile 2>/dev/null; then
    log_fail "Configuration check failed: Shadowing directory '/root/scripts' is still prepended to PATH in startup files."
fi

log_pass "PATH configuration in startup files is clean."

echo "=================================================="
echo -e "${GREEN}ALL PATH SHADOWING CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
