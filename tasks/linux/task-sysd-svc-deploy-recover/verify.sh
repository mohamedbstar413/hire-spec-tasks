#!/usr/bin/env bash
set -euo pipefail

# Color Output Formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

SERVICE_NAME="webapp.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
PORT=5000

echo "=================================================="
echo " Verifying Lab 2: Systemd Service Deployment & Recovery"
echo "=================================================="

# ---------------------------------------------------------
# Check 1: Unit File Existence
# ---------------------------------------------------------
log_info "Check 1: Verifying systemd unit file at $SERVICE_PATH..."
if [[ ! -f "$SERVICE_PATH" ]]; then
    log_fail "Systemd unit file not found at $SERVICE_PATH."
fi
log_pass "Systemd unit file exists at $SERVICE_PATH."

# ---------------------------------------------------------
# Check 2: Static Analysis of Unit File (User, Restart, ExecStart)
# ---------------------------------------------------------
log_info "Check 2: Validating unit file configuration (User, Restart directive)..."

if ! grep -qE '^[[:space:]]*User[[:space:]]*=[[:space:]]*webapp' "$SERVICE_PATH"; then
    log_fail "Unit file does not set 'User=webapp'."
fi

if ! grep -qE '^[[:space:]]*Restart[[:space:]]*=[[:space:]]*(on-failure|always)' "$SERVICE_PATH"; then
    log_fail "Unit file does not contain valid 'Restart=on-failure' or 'Restart=always' directive."
fi

if ! grep -qE '^[[:space:]]*ExecStart[[:space:]]*=' "$SERVICE_PATH"; then
    log_fail "Unit file missing 'ExecStart' directive."
fi
log_pass "Unit file contains required User=webapp, Restart directive, and ExecStart."

# ---------------------------------------------------------
# Check 3: System User Existence
# ---------------------------------------------------------
log_info "Check 3: Verifying system user 'webapp'..."
if ! id webapp >/dev/null 2>&1; then
    log_fail "Dedicated service user 'webapp' does not exist."
fi
log_pass "User 'webapp' exists."

# ---------------------------------------------------------
# Check 4: Service Enabled & Active Status
# ---------------------------------------------------------
log_info "Check 4: Checking systemd service state (enabled & active)..."

if ! systemctl is-enabled webapp >/dev/null 2>&1; then
    log_fail "Service 'webapp' is not enabled to start on boot."
fi
log_pass "Service 'webapp' is enabled."

if ! systemctl is-active webapp >/dev/null 2>&1; then
    log_info "Systemctl status for webapp:"
    systemctl status webapp || true
    log_fail "Service 'webapp' is not currently active/running."
fi
log_pass "Service 'webapp' is active and running."

# ---------------------------------------------------------
# Check 5: Port Listening & Health Check
# ---------------------------------------------------------
log_info "Check 5: Verifying application is listening on port $PORT..."

PORT_LISTENING=false
if ss -tlnp 2>/dev/null | grep -q ":${PORT}"; then
    PORT_LISTENING=true
elif curl -s "http://localhost:${PORT}" >/dev/null 2>&1; then
    PORT_LISTENING=true
fi

if [[ "$PORT_LISTENING" = false ]]; then
    log_fail "No application is listening on port $PORT."
fi
log_pass "Application listening on port $PORT verified."

# ---------------------------------------------------------
# Check 6: Process Crash & Systemd Auto-Recovery Test
# ---------------------------------------------------------
log_info "Check 6: Testing crash recovery (killing main PID)..."

INITIAL_PID=$(systemctl show --property=MainPID webapp.service | cut -d= -f2)
if [[ -z "$INITIAL_PID" || "$INITIAL_PID" -eq 0 ]]; then
    log_fail "Failed to determine MainPID for webapp.service."
fi

log_info "Killing webapp process (PID: $INITIAL_PID) with SIGKILL..."
kill -9 "$INITIAL_PID" || true

# Give systemd time to detect failure and restart process
sleep 3

RERESTART_PID=$(systemctl show --property=MainPID webapp.service | cut -d= -f2)

if ! systemctl is-active webapp >/dev/null 2>&1; then
    log_fail "Service failed to automatically restart after process kill."
fi

if [[ "$INITIAL_PID" -eq "$RERESTART_PID" ]]; then
    log_fail "Process PID did not change after kill; auto-recovery did not trigger a new process."
fi

log_pass "Crash recovery verified! Service restarted with new PID ($RERESTART_PID)."

echo "=================================================="
echo -e "${GREEN}ALL LAB 2 VERIFICATION CHECKS PASSED SUCCESSFULLY!${NC}"
echo "=================================================="
exit 0
