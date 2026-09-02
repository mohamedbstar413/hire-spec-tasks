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
echo " Verifying Task: Systemd Environment Variable Fix"
echo "=================================================="

# 1. Check systemctl status of configapp.service
log_info "Checking systemd service active status..."
if ! systemctl is-active --quiet configapp.service; then
    log_fail "Service check failed: 'configapp.service' is not active/running."
fi
log_pass "'configapp.service' is active and running."

# 2. Check service logs for successful startup
log_info "Checking journal logs for 'Started with key:' entry..."
JOURNAL_LOGS=$(journalctl -u configapp.service -n 25 --no-pager 2>&1 || true)

if ! echo "$JOURNAL_LOGS" | grep -q "Started with key:"; then
    log_fail "Log check failed: 'Started with key:' log entry not found in journalctl.\nLogs:\n$JOURNAL_LOGS"
fi

if echo "$JOURNAL_LOGS" | tail -n 5 | grep -q "FATAL: API_KEY is not set"; then
    log_fail "Log check failed: Service is still outputting 'FATAL: API_KEY is not set'."
fi

log_pass "Journal logs confirm service started successfully with API_KEY."

# 3. Check systemd unit file configuration for Environment setting
log_info "Checking systemd unit configuration for Environment setting..."
SHOW_ENV=$(systemctl show configapp.service -p Environment --value 2>/dev/null || true)

if [[ -z "$SHOW_ENV" ]] && ! grep -rq "API_KEY" /etc/systemd/system/configapp.service* /etc/systemd/system/configapp.service.d/ 2>/dev/null; then
    log_fail "Configuration check failed: API_KEY is not configured in systemd unit or drop-in files."
fi

log_pass "Systemd environment configuration verified."

echo "=================================================="
echo -e "${GREEN}ALL SYSTEMD ENVIRONMENT CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
