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
echo " Verifying Task: Terminate Unkillable D-State Process"
echo "=================================================="

log_info "Checking if any '/opt/scripts/stuck_app' process is still running..."

# Check ps aux for stuck_app
STUCK_PIDS=$(pgrep -f "stuck_app" || true)

if [[ -n "$STUCK_PIDS" ]]; then
    log_fail "Process check failed: The process 'stuck_app' is still running with PID(s): $STUCK_PIDS"
fi

log_pass "No 'stuck_app' processes found in process table."

# Check if stuck-app service was stopped or disabled to prevent auto-restart loop
log_info "Checking systemd service status..."
if systemctl is-active --quiet stuck-app.service 2>/dev/null; then
    log_fail "Service check failed: 'stuck-app.service' is still active."
fi

log_pass "Service successfully stopped."

echo "=================================================="
echo -e "${GREEN}ALL UNKILLABLE PROCESS CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
