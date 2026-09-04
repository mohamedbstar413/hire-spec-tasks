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
echo " Verifying Task: Graceful Shutdown & SIGTERM Fix"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check /app/start.sh or Dockerfile for exec / trap / direct CMD
log_info "Checking /app files for signal propagation implementation..."
if [[ ! -f /app/Dockerfile ]]; then
    log_fail "File /app/Dockerfile is missing."
fi

# 3. Build image from /app/Dockerfile
log_info "Building image 'myapp-shutdown:latest' from /app/Dockerfile..."
if ! docker build -t myapp-shutdown:latest /app >/tmp/docker_build.log 2>&1; then
    log_fail "Failed to build image from /app/Dockerfile. Build log:\n$(cat /tmp/docker_build.log)"
fi
log_pass "Successfully built image 'myapp-shutdown:latest'."

# 4. Clean up any existing test containers
docker rm -f verify_test_shutdown >/dev/null 2>&1 || true

# 5. Launch test container
log_info "Running test container from 'myapp-shutdown:latest'..."
if ! docker run -d --name verify_test_shutdown myapp-shutdown:latest >/tmp/docker_run.log 2>&1; then
    log_fail "Failed to launch container: $(cat /tmp/docker_run.log)"
fi

sleep 2

# 6. Measure docker stop execution time
log_info "Testing container shutdown time with 'docker stop -t 5'..."
START_TIME=$(date +%s)
docker stop -t 5 verify_test_shutdown >/dev/null 2>&1 || true
END_TIME=$(date +%s)

STOP_DURATION=$((END_TIME - START_TIME))
log_info "Container stop duration: ${STOP_DURATION} seconds."

# Check exit code of stopped container
EXIT_CODE=$(docker inspect verify_test_shutdown --format='{{.State.ExitCode}}' 2>/dev/null || echo "137")

if [[ "$STOP_DURATION" -ge 4 ]]; then
    LOG_OUTPUT=$(docker logs verify_test_shutdown 2>&1 || true)
    docker rm -f verify_test_shutdown >/dev/null 2>&1 || true
    log_fail "Graceful shutdown check failed: 'docker stop' took ${STOP_DURATION}s (Exceeded 3s limit). Container did not handle SIGTERM.\nLogs:\n$LOG_OUTPUT"
fi

if [[ "$EXIT_CODE" != "0" ]]; then
    LOG_OUTPUT=$(docker logs verify_test_shutdown 2>&1 || true)
    docker rm -f verify_test_shutdown >/dev/null 2>&1 || true
    log_fail "Exit code check failed: Container exited with status $EXIT_CODE (Expected 0 for graceful shutdown). Logs:\n$LOG_OUTPUT"
fi

log_pass "Container stopped quickly (${STOP_DURATION}s) with ExitCode 0."

# 7. Check container logs for graceful shutdown output
log_info "Inspecting container logs for SIGTERM handler output..."
CONTAINER_LOGS=$(docker logs verify_test_shutdown 2>&1 || true)

if ! echo "$CONTAINER_LOGS" | grep -iq "Shutting down gracefully"; then
    docker rm -f verify_test_shutdown >/dev/null 2>&1 || true
    log_fail "Log check failed: Container logs do not confirm graceful shutdown ('Shutting down gracefully').\nLogs:\n$CONTAINER_LOGS"
fi

log_pass "Confirmed log entry: 'Received SIGTERM. Shutting down gracefully...'."

# Clean up
docker rm -f verify_test_shutdown >/dev/null 2>&1 || true

echo "=================================================="
echo -e "${GREEN}ALL GRACEFUL SHUTDOWN CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
