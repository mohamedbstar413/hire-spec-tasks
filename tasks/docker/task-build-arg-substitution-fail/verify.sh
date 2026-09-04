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
echo " Verifying Task: Build Argument Substitution Fix"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check /app/Dockerfile for ARG declaration
log_info "Checking /app/Dockerfile for ARG APP_ENV declaration..."
if [[ ! -f /app/Dockerfile ]]; then
    log_fail "File /app/Dockerfile is missing."
fi

if ! grep -qE "ARG[[:space:]]+APP_ENV" /app/Dockerfile; then
    log_fail "Dockerfile check failed: /app/Dockerfile does not declare 'ARG APP_ENV'."
fi
log_pass "/app/Dockerfile explicitly declares 'ARG APP_ENV'."

# 3. Build image passing --build-arg APP_ENV=production
log_info "Building image 'myapp-env:latest' with --build-arg APP_ENV=production..."
if ! docker build --build-arg APP_ENV=production -t myapp-env:latest /app >/tmp/docker_build.log 2>&1; then
    log_fail "Failed to build image with --build-arg APP_ENV=production. Build log:\n$(cat /tmp/docker_build.log)"
fi
log_pass "Successfully built image 'myapp-env:latest'."

# 4. Clean up existing test container
docker rm -f verify_test_arg_app >/dev/null 2>&1 || true

# 5. Run test container
log_info "Running test container from 'myapp-env:latest'..."
if ! docker run -d --name verify_test_arg_app myapp-env:latest >/tmp/docker_run.log 2>&1; then
    log_fail "Failed to launch container: $(cat /tmp/docker_run.log)"
fi

sleep 3

# 6. Inspect container state and logs
log_info "Inspecting container logs for successful ARG substitution..."
CONTAINER_STATE=$(docker inspect verify_test_arg_app --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
EXIT_CODE=$(docker inspect verify_test_arg_app --format='{{.State.ExitCode}}' 2>/dev/null || echo "1")

if [[ "$CONTAINER_STATE" != "running" || "$EXIT_CODE" != "0" ]]; then
    LOG_OUTPUT=$(docker logs verify_test_arg_app 2>&1 || true)
    docker rm -f verify_test_arg_app >/dev/null 2>&1 || true
    log_fail "Container failed to remain active! Status: '$CONTAINER_STATE', ExitCode: $EXIT_CODE.\nLogs:\n$LOG_OUTPUT"
fi

CONTAINER_LOGS=$(docker logs verify_test_arg_app 2>&1 || true)

if echo "$CONTAINER_LOGS" | grep -iq "FATAL"; then
    docker rm -f verify_test_arg_app >/dev/null 2>&1 || true
    log_fail "Substitution check failed: Container encountered error:\n$CONTAINER_LOGS"
fi

if ! echo "$CONTAINER_LOGS" | grep -iq "SUCCESS: APP_ENV build arg substituted"; then
    docker rm -f verify_test_arg_app >/dev/null 2>&1 || true
    log_fail "Log check failed: Container logs do not confirm ARG substitution.\nLogs:\n$CONTAINER_LOGS"
fi

log_pass "Confirmed log entry: 'SUCCESS: APP_ENV build arg substituted correctly (value: production)!'"

# Clean up
docker rm -f verify_test_arg_app >/dev/null 2>&1 || true

echo "=================================================="
echo -e "${GREEN}ALL BUILD ARG SUBSTITUTION CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
