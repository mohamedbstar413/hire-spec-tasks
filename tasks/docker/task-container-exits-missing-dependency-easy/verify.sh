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
echo " Verifying Task: Fix Container Missing Dependency"
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

# 3. Verify Dockerfile contains pip install flask
if ! grep -iq "flask" /app/Dockerfile; then
    log_fail "Dockerfile check failed: /app/Dockerfile does not contain instructions to install 'flask'."
fi
log_pass "Dockerfile contains dependency installation instruction."

# 4. Test building image from /app/Dockerfile
log_info "Building image 'myapp-web:latest' from /app/Dockerfile..."
if ! docker build -t myapp-web:latest /app >/tmp/docker_build.log 2>&1; then
    log_fail "Failed to build image from /app/Dockerfile. Build log:\n$(cat /tmp/docker_build.log)"
fi
log_pass "Successfully built image 'myapp-web:latest'."

# 5. Clean up any existing verify test container
docker rm -f verify_test_web >/dev/null 2>&1 || true

# 6. Test running container from myapp-web:latest
log_info "Running container from 'myapp-web:latest'..."
if ! docker run -d --name verify_test_web -p 5000:5000 myapp-web:latest >/tmp/docker_run.log 2>&1; then
    log_fail "Failed to launch container from 'myapp-web:latest': $(cat /tmp/docker_run.log)"
fi

sleep 4

# 7. Inspect container state
log_info "Inspecting container state..."
CONTAINER_STATE=$(docker inspect verify_test_web --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
EXIT_CODE=$(docker inspect verify_test_web --format='{{.State.ExitCode}}' 2>/dev/null || echo "1")

if [[ "$CONTAINER_STATE" != "running" || "$EXIT_CODE" != "0" ]]; then
    LOG_OUTPUT=$(docker logs verify_test_web 2>&1 || true)
    docker rm -f verify_test_web >/dev/null 2>&1 || true
    log_fail "Container failed to stay running! Status: '$CONTAINER_STATE', ExitCode: $EXIT_CODE.\nContainer Logs:\n$LOG_OUTPUT"
fi

log_pass "Container is actively running (Status: running, ExitCode: 0)."

# 8. Test HTTP endpoint response
log_info "Testing HTTP endpoint response on port 5000..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/ || true)

if [[ "$HTTP_CODE" != "200" ]]; then
    docker rm -f verify_test_web >/dev/null 2>&1 || true
    log_fail "HTTP check failed: Application endpoint returned status code $HTTP_CODE (Expected 200)."
fi

log_pass "Application endpoint successfully returned HTTP status 200 OK."

# Cleanup test container
docker rm -f verify_test_web >/dev/null 2>&1 || true

echo "=================================================="
echo -e "${GREEN}ALL MISSING DEPENDENCY CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
