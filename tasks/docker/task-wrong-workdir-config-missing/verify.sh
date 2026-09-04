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
echo " Verifying Task: Correct Dockerfile WORKDIR Setup"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check /app/Dockerfile
log_info "Checking /app/Dockerfile..."
if [[ ! -f /app/Dockerfile ]]; then
    log_fail "File /app/Dockerfile is missing."
fi

# 3. Verify Dockerfile contains WORKDIR /app
log_info "Checking WORKDIR directive in /app/Dockerfile..."
if ! grep -Eq "WORKDIR[[:space:]]+/app(/)?" /app/Dockerfile; then
    log_fail "Dockerfile check failed: /app/Dockerfile does not set 'WORKDIR /app'."
fi
log_pass "/app/Dockerfile explicitly sets 'WORKDIR /app'."

# 4. Build image from /app/Dockerfile
log_info "Building image 'myapp-config:latest' from /app/Dockerfile..."
if ! docker build -t myapp-config:latest /app >/tmp/docker_build.log 2>&1; then
    log_fail "Failed to build image from /app/Dockerfile. Build log:\n$(cat /tmp/docker_build.log)"
fi
log_pass "Successfully built image 'myapp-config:latest'."

# 5. Clean up any existing test containers
docker rm -f verify_test_workdir >/dev/null 2>&1 || true

# 6. Run container from myapp-config:latest
log_info "Launching test container from 'myapp-config:latest'..."
if ! docker run -d --name verify_test_workdir myapp-config:latest >/tmp/docker_run.log 2>&1; then
    log_fail "Failed to launch container: $(cat /tmp/docker_run.log)"
fi

sleep 3

# 7. Inspect container state & working directory
log_info "Inspecting container state and working directory..."
CONTAINER_STATE=$(docker inspect verify_test_workdir --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
EXIT_CODE=$(docker inspect verify_test_workdir --format='{{.State.ExitCode}}' 2>/dev/null || echo "1")
WORKDIR_VAL=$(docker inspect verify_test_workdir --format='{{.Config.WorkingDir}}' 2>/dev/null || echo "")

if [[ "$CONTAINER_STATE" != "running" || "$EXIT_CODE" != "0" ]]; then
    LOG_OUTPUT=$(docker logs verify_test_workdir 2>&1 || true)
    docker rm -f verify_test_workdir >/dev/null 2>&1 || true
    log_fail "Container failed to remain active! Status: '$CONTAINER_STATE', ExitCode: $EXIT_CODE.\nLogs:\n$LOG_OUTPUT"
fi

if [[ "$WORKDIR_VAL" != "/app" && "$WORKDIR_VAL" != "/app/" ]]; then
    docker rm -f verify_test_workdir >/dev/null 2>&1 || true
    log_fail "Working directory check failed: Image WorkingDir is '$WORKDIR_VAL' (Expected '/app')."
fi

log_pass "Container is actively running and WorkingDir is set to '/app'."

# 8. Inspect container logs for success message
log_info "Checking container logs for configuration loading output..."
CONTAINER_LOGS=$(docker logs verify_test_workdir 2>&1 || true)

if echo "$CONTAINER_LOGS" | grep -iq "FATAL ERROR"; then
    docker rm -f verify_test_workdir >/dev/null 2>&1 || true
    log_fail "Log check failed: Container encountered error finding config file:\n$CONTAINER_LOGS"
fi

if ! echo "$CONTAINER_LOGS" | grep -iq "SUCCESS: Loaded config successfully"; then
    docker rm -f verify_test_workdir >/dev/null 2>&1 || true
    log_fail "Log check failed: Container logs do not confirm successful config load.\nLogs:\n$CONTAINER_LOGS"
fi

log_pass "Confirmed log entry: 'SUCCESS: Loaded config successfully! DB Host: localhost'."

# Clean up
docker rm -f verify_test_workdir >/dev/null 2>&1 || true

echo "=================================================="
echo -e "${GREEN}ALL WORKDIR CONFIG CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
