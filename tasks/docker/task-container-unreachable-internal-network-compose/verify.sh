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
echo " Verifying Task: Container Network Internal Isolation Fix"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check /app/docker-compose.yml for internal: true removal
log_info "Checking /app/docker-compose.yml network definition..."
if [[ ! -f /app/docker-compose.yml ]]; then
    log_fail "File /app/docker-compose.yml is missing."
fi

if grep -qE "internal:[[:space:]]*true" /app/docker-compose.yml; then
    log_fail "Compose check failed: /app/docker-compose.yml still has 'internal: true' under networks."
fi
log_pass "/app/docker-compose.yml does not have 'internal: true'."

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

# 4. Get container IP and test HTTP reachability
CONTAINER_NAME="unreachable_web_app"
CONTAINER_IP=$(docker inspect "$CONTAINER_NAME" --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "")

log_info "Testing HTTP connectivity to container IP ($CONTAINER_IP:8080)..."
if [[ -z "$CONTAINER_IP" ]]; then
    $COMPOSE_CMD down -v >/dev/null 2>&1 || true
    log_fail "Could not determine container IP address."
fi

HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" --connect-timeout 4 "http://${CONTAINER_IP}:8080/" || true)
HTTP_BODY=$(echo "$HTTP_RESPONSE" | head -n 1)
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n 1)

if [[ "$HTTP_STATUS" != "200" ]]; then
    $COMPOSE_CMD down -v >/dev/null 2>&1 || true
    log_fail "Reachability check failed: Connection to $CONTAINER_IP:8080 returned status '$HTTP_STATUS' (Expected 200)."
fi

log_pass "Successfully reached container IP $CONTAINER_IP:8080 (HTTP 200 OK)."

# Clean up
$COMPOSE_CMD down -v >/dev/null 2>&1 || true

echo "=================================================="
echo -e "${GREEN}ALL INTERNAL NETWORK CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
