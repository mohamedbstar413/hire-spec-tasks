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
echo " Verifying Task: Fix Exiting Container"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check if Dockerfile in /app exists
log_info "Checking /app/Dockerfile..."
if [[ ! -f /app/Dockerfile ]]; then
    log_fail "File /app/Dockerfile is missing."
fi

# 3. Test building image from /app/Dockerfile
log_info "Building image 'myapp:latest' from /app/Dockerfile..."
if ! docker build -t myapp:latest /app >/tmp/docker_build.log 2>&1; then
    log_fail "Failed to build image from /app/Dockerfile. Build log:\n$(cat /tmp/docker_build.log)"
fi
log_pass "Successfully built image 'myapp:latest'."

# 4. Clean up any existing verify test container
docker rm -f verify_test_app >/dev/null 2>&1 || true

# 5. Test running container from myapp:latest
log_info "Running container from 'myapp:latest'..."
if ! docker run -d --name verify_test_app myapp:latest >/tmp/docker_run.log 2>&1; then
    log_fail "Failed to launch container from 'myapp:latest': $(cat /tmp/docker_run.log)"
fi

sleep 3

# 6. Inspect container state
log_info "Inspecting container state..."
CONTAINER_STATE=$(docker inspect verify_test_app --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
EXIT_CODE=$(docker inspect verify_test_app --format='{{.State.ExitCode}}' 2>/dev/null || echo "1")

if [[ "$CONTAINER_STATE" != "running" || "$EXIT_CODE" != "0" ]]; then
    LOG_OUTPUT=$(docker logs verify_test_app 2>&1 || true)
    docker rm -f verify_test_app >/dev/null 2>&1 || true
    log_fail "Container failed to stay running! Status: '$CONTAINER_STATE', ExitCode: $EXIT_CODE.\nContainer Logs:\n$LOG_OUTPUT"
fi

log_pass "Container is actively running (Status: running, ExitCode: 0)."

# Cleanup test container
docker rm -f verify_test_app >/dev/null 2>&1 || true

echo "=================================================="
echo -e "${GREEN}ALL CONTAINER EXIT CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
