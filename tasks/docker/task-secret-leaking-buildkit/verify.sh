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
echo " Verifying Task: Prevent Secret Leaks via BuildKit Secrets"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check /app/Dockerfile for secret mount syntax
log_info "Checking /app/Dockerfile for BuildKit secret mount..."
if [[ ! -f /app/Dockerfile ]]; then
    log_fail "File /app/Dockerfile is missing."
fi

if ! grep -q "\-\-mount=type=secret" /app/Dockerfile; then
    log_fail "Dockerfile check failed: /app/Dockerfile does not use '--mount=type=secret'."
fi
log_pass "/app/Dockerfile uses '--mount=type=secret'."

# 3. Check for secret file
SECRET_FILE="/app/secret.txt"
if [[ ! -f "$SECRET_FILE" ]]; then
    log_fail "Secret file $SECRET_FILE is missing."
fi

SECRET_VAL=$(cat "$SECRET_FILE" | tr -d '\n\r')

# 4. Build image using BuildKit and secret mount
log_info "Building image 'myapp-secret:latest' with BuildKit secret mount..."
export DOCKER_BUILDKIT=1
if ! docker build --secret id=api_key,src="$SECRET_FILE" -t myapp-secret:latest /app >/tmp/docker_build.log 2>&1; then
    log_fail "Failed to build image with BuildKit secret mount. Build log:\n$(cat /tmp/docker_build.log)"
fi
log_pass "Successfully built image 'myapp-secret:latest'."

# 5. Inspect docker history for secret leakage
log_info "Inspecting docker history for secret value leakage..."
HISTORY_OUT=$(docker history myapp-secret:latest 2>&1 || true)

if echo "$HISTORY_OUT" | grep -q "$SECRET_VAL"; then
    log_fail "Security check failed: Secret '$SECRET_VAL' was found in 'docker history'!"
fi
log_pass "Secret is NOT present in 'docker history'."

# 6. Inspect docker inspect metadata for secret leakage
log_info "Inspecting docker inspect for secret value leakage..."
INSPECT_OUT=$(docker inspect myapp-secret:latest 2>&1 || true)

if echo "$INSPECT_OUT" | grep -q "$SECRET_VAL"; then
    log_fail "Security check failed: Secret '$SECRET_VAL' was found in 'docker inspect' metadata!"
fi
log_pass "Secret is NOT present in 'docker inspect' metadata."

# 7. Test running container
log_info "Running test container from 'myapp-secret:latest'..."
docker rm -f verify_secret_app >/dev/null 2>&1 || true
if ! docker run -d --name verify_secret_app myapp-secret:latest >/tmp/docker_run.log 2>&1; then
    log_fail "Failed to launch container: $(cat /tmp/docker_run.log)"
fi

sleep 2

STATUS=$(docker inspect verify_secret_app --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
if [[ "$STATUS" != "running" ]]; then
    LOGS=$(docker logs verify_secret_app 2>&1 || true)
    docker rm -f verify_secret_app >/dev/null 2>&1 || true
    log_fail "Container failed to run cleanly (Status: $STATUS). Logs:\n$LOGS"
fi

log_pass "Container is actively running."

# Cleanup
docker rm -f verify_secret_app >/dev/null 2>&1 || true

echo "=================================================="
echo -e "${GREEN}ALL BUILDKIT SECRET CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
