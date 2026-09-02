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
echo " Verifying Task: Stale Ghost PID File Fix"
echo "=================================================="

# 1. Check systemd service active status
log_info "Checking systemd service active status..."
if ! systemctl is-active --quiet pidapp.service; then
    log_fail "Service check failed: 'pidapp.service' is not active/running."
fi
log_pass "'pidapp.service' is active and running."

# 2. Check running process
log_info "Verifying running python process..."
RUNNING_PID=$(pgrep -f "/opt/pidapp/app.py" || true)

if [[ -z "$RUNNING_PID" ]]; then
    log_fail "Process check failed: No process running '/opt/pidapp/app.py' was found."
fi
log_pass "Running process found with PID: $RUNNING_PID"

# 3. Check PID file content matches active PID
log_info "Verifying /run/pidapp/app.pid content..."
if [[ ! -f /run/pidapp/app.pid ]]; then
    log_fail "PID file check failed: '/run/pidapp/app.pid' does not exist."
fi

PIDFILE_CONTENT=$(cat /run/pidapp/app.pid | tr -d ' \r\n')

if [[ "$PIDFILE_CONTENT" == "99999" ]]; then
    log_fail "PID file check failed: '/run/pidapp/app.pid' still contains stale PID '99999'."
fi

if [[ "$PIDFILE_CONTENT" != "$RUNNING_PID" ]]; then
    log_fail "PID file check failed: '/run/pidapp/app.pid' contains '$PIDFILE_CONTENT', expected live PID '$RUNNING_PID'."
fi

log_pass "PID file contains valid live PID: $PIDFILE_CONTENT"

# 4. Check journalctl logs
log_info "Checking journal logs for 'Started cleanly' entry..."
JOURNAL_LOGS=$(journalctl -u pidapp.service -n 25 --no-pager 2>&1 || true)

if ! echo "$JOURNAL_LOGS" | grep -q "Started cleanly"; then
    log_fail "Log check failed: 'Started cleanly' log entry not found in journalctl.\nLogs:\n$JOURNAL_LOGS"
fi

log_pass "Journal logs confirm service started cleanly."

echo "=================================================="
echo -e "${GREEN}ALL GHOST PID FILE CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
