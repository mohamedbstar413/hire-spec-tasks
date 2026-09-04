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
echo " Verifying Task: Compose Logs Redirection Fix"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check /app/start.sh or Dockerfile for log redirection removal
log_info "Checking /app/start.sh for log redirection removal..."
if [[ -f /app/start.sh ]]; then
    if grep -q ">[[:space:]]*/var/log" /app/start.sh || grep -q "2>&1" /app/start.sh; then
        log_fail "Code check failed: /app/start.sh still redirects output to file ('/var/log/...')."
    fi
    log_pass "/app/start.sh does not contain file output redirection."
fi

# 3. Launch Docker Compose service
log_info "Launching Docker Compose services..."
cd /app
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

$COMPOSE_CMD up -d --build >/tmp/compose_up.log 2>&1 || log_fail "Failed to run '$COMPOSE_CMD up -d'. Output:\n$(cat /tmp/compose_up.log)"
log_pass "Successfully launched Docker Compose services."

sleep 4

# 4. Inspect container logs via docker logs
log_info "Inspecting container logs for stdout output..."
CONTAINER_NAME="app_logger_service"

RUNNING_STATUS=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
if [[ "$RUNNING_STATUS" != "running" ]]; then
    $COMPOSE_CMD down -v >/dev/null 2>&1 || true
    log_fail "Service check failed: Container '$CONTAINER_NAME' is not running (Status: $RUNNING_STATUS)."
fi

LOG_OUTPUT=$(docker logs "$CONTAINER_NAME" 2>&1 || true)

if [[ -z "$LOG_OUTPUT" ]]; then
    $COMPOSE_CMD down -v >/dev/null 2>&1 || true
    log_fail "Log check failed: 'docker logs $CONTAINER_NAME' returned empty output!"
fi

if ! echo "$LOG_OUTPUT" | grep -iq "API Service initialized successfully"; then
    $COMPOSE_CMD down -v >/dev/null 2>&1 || true
    log_fail "Log check failed: Container logs do not contain 'API Service initialized successfully'. Received:\n$LOG_OUTPUT"
fi

log_pass "Confirmed stdout log output: 'API Service initialized successfully'."

# Clean up
$COMPOSE_CMD down -v >/dev/null 2>&1 || true

echo "=================================================="
echo -e "${GREEN}ALL LOG REDIRECTION CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
