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
echo " Verifying Task: Compose Healthcheck Endpoint Fix"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check /app/docker-compose.yml for corrected endpoint
log_info "Checking /app/docker-compose.yml healthcheck definition..."
if [[ ! -f /app/docker-compose.yml ]]; then
    log_fail "File /app/docker-compose.yml is missing."
fi

if grep -q "healthz" /app/docker-compose.yml; then
    log_fail "Compose check failed: /app/docker-compose.yml still references the incorrect endpoint '/healthz'."
fi

if ! grep -q "health" /app/docker-compose.yml; then
    log_fail "Compose check failed: /app/docker-compose.yml does not reference the correct endpoint '/health'."
fi
log_pass "/app/docker-compose.yml specifies correct endpoint '/health'."

# 3. Test running docker compose up -d
log_info "Starting Docker Compose services..."
cd /app
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

$COMPOSE_CMD up -d --build >/tmp/compose_up.log 2>&1 || log_fail "Failed to run '$COMPOSE_CMD up -d'. Output:\n$(cat /tmp/compose_up.log)"
log_pass "Successfully launched Docker Compose services."

sleep 8

# 4. Inspect container health status
log_info "Inspecting container health status..."
CONTAINER_NAME="web_api_service"

HEALTH_STATUS=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
RUNNING_STATUS=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Status}}' 2>/dev/null || echo "unknown")

if [[ "$RUNNING_STATUS" != "running" ]]; then
    LOGS=$(docker logs "$CONTAINER_NAME" 2>&1 || true)
    $COMPOSE_CMD down -v >/dev/null 2>&1 || true
    log_fail "Service check failed: Container is not running (Status: $RUNNING_STATUS). Logs:\n$LOGS"
fi

if [[ "$HEALTH_STATUS" != "healthy" ]]; then
    HEALTH_LOGS=$(docker inspect "$CONTAINER_NAME" --format='{{json .State.Health}}' 2>/dev/null || true)
    LOGS=$(docker logs "$CONTAINER_NAME" 2>&1 || true)
    $COMPOSE_CMD down -v >/dev/null 2>&1 || true
    log_fail "Healthcheck check failed: Container health status is '$HEALTH_STATUS' (Expected 'healthy'). Health Log:\n$HEALTH_LOGS\nApp Logs:\n$LOGS"
fi

log_pass "Container '$CONTAINER_NAME' is active and HEALTHY (Status: healthy)."

# Clean up
$COMPOSE_CMD down -v >/dev/null 2>&1 || true

echo "=================================================="
echo -e "${GREEN}ALL COMPOSE HEALTHCHECK CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
