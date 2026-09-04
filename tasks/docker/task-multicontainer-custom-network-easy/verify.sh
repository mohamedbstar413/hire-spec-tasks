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
echo " Verifying Task: Multi-Container Custom Network DNS"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check Dockerfiles
log_info "Checking Dockerfiles in /app/backend and /app/frontend..."
if [[ ! -f /app/backend/Dockerfile || ! -f /app/frontend/Dockerfile ]]; then
    log_fail "Missing Dockerfiles in /app/backend or /app/frontend."
fi
log_pass "Both Dockerfiles are present."

# 3. Check for custom user-defined networks
log_info "Inspecting user-defined Docker networks..."
CUSTOM_NETWORKS=$(docker network ls --format '{{.Name}}' | grep -vE "^(bridge|host|none)$" || true)

if [[ -z "$CUSTOM_NETWORKS" ]]; then
    log_fail "Network check failed: No user-defined custom Docker network was created. (Default bridge network does not support container name DNS resolution)."
fi
log_pass "Found custom user-defined Docker network(s): $CUSTOM_NETWORKS"

# 4. Check if backend-api and frontend-app containers are running
log_info "Checking running containers..."
BACKEND_RUNNING=$(docker ps --filter "name=backend" --format '{{.Names}}' || true)
FRONTEND_RUNNING=$(docker ps --filter "name=frontend" --format '{{.Names}}' || true)

if [[ -z "$BACKEND_RUNNING" ]]; then
    log_fail "Container check failed: Backend container (name containing 'backend') is not running."
fi

if [[ -z "$FRONTEND_RUNNING" ]]; then
    log_fail "Container check failed: Frontend container (name containing 'frontend') is not running."
fi

log_pass "Backend ($BACKEND_RUNNING) and Frontend ($FRONTEND_RUNNING) containers are running."

# 5. Check frontend logs for successful backend connection
log_info "Checking frontend container logs..."
FRONTEND_LOGS=$(docker logs "$FRONTEND_RUNNING" 2>&1 || true)

if echo "$FRONTEND_LOGS" | grep -iq "FAILED to connect"; then
    log_fail "Connectivity check failed: Frontend container failed to connect to backend:\n$FRONTEND_LOGS"
fi

if ! echo "$FRONTEND_LOGS" | grep -iq "Backend Response Code: 200"; then
    log_fail "Response check failed: Frontend logs do not contain 'Backend Response Code: 200'.\nLogs:\n$FRONTEND_LOGS"
fi

log_pass "Frontend container successfully connected to backend using container name (HTTP 200 OK)."

echo "=================================================="
echo -e "${GREEN}ALL MULTI-CONTAINER NETWORK CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
