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
echo " Verifying Task: Volume Permission Fix with Gosu"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check /app/Dockerfile and entrypoint script
log_info "Checking /app/Dockerfile for ENTRYPOINT and gosu..."
if [[ ! -f /app/Dockerfile ]]; then
    log_fail "File /app/Dockerfile is missing."
fi

if ! grep -iq "ENTRYPOINT" /app/Dockerfile; then
    log_fail "Dockerfile check failed: /app/Dockerfile does not configure an ENTRYPOINT."
fi

ENTRYPOINT_SCRIPT=$(grep -i "ENTRYPOINT" /app/Dockerfile | grep -oE '[a-zA-Z0-9_\.\/-]+entrypoint[a-zA-Z0-9_\.\/-]*' | head -n 1 || echo "")

if [[ -n "$ENTRYPOINT_SCRIPT" && -f "/app/$ENTRYPOINT_SCRIPT" ]]; then
    SCRIPT_PATH="/app/$ENTRYPOINT_SCRIPT"
elif [[ -f /app/entrypoint.sh ]]; then
    SCRIPT_PATH="/app/entrypoint.sh"
else
    SCRIPT_PATH=""
fi

if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
    log_info "Inspecting entrypoint script ($SCRIPT_PATH)..."
    if ! grep -q "gosu" "$SCRIPT_PATH" && ! grep -q "chown" "$SCRIPT_PATH" && ! grep -q "chmod" "$SCRIPT_PATH"; then
        log_fail "Entrypoint check failed: $SCRIPT_PATH does not contain gosu / chown / chmod privilege dropping logic."
    fi
    log_pass "Entrypoint script contains privilege dropping logic."
else
    log_info "No separate entrypoint.sh file found in /app; verifying image execution directly..."
fi

# 3. Test building image from /app/Dockerfile
log_info "Building image 'myapp:latest' from /app/Dockerfile..."
if ! docker build -t myapp:latest /app >/tmp/docker_build.log 2>&1; then
    log_fail "Failed to build image from /app/Dockerfile. Build log:\n$(cat /tmp/docker_build.log)"
fi
log_pass "Successfully built image 'myapp:latest'."

# 4. Prepare root-owned host test directory to simulate volume permission conflict
TEST_VOL_DIR="/tmp/test_verify_vol"
mkdir -p "$TEST_VOL_DIR"
chown root:root "$TEST_VOL_DIR"
chmod 755 "$TEST_VOL_DIR"

# Clean up existing test container
docker rm -f verify_test_gosu_app >/dev/null 2>&1 || true

# 5. Run container with root-owned mounted volume
log_info "Running test container with mounted volume ($TEST_VOL_DIR:/app/data)..."
if ! docker run -d -v "$TEST_VOL_DIR:/app/data" --name verify_test_gosu_app myapp:latest >/tmp/docker_run.log 2>&1; then
    log_fail "Failed to launch container: $(cat /tmp/docker_run.log)"
fi

sleep 4

# 6. Check logs for success message
log_info "Checking container logs..."
CONTAINER_LOGS=$(docker logs verify_test_gosu_app 2>&1 || true)

if echo "$CONTAINER_LOGS" | grep -iq "Permission denied"; then
    docker rm -f verify_test_gosu_app >/dev/null 2>&1 || true
    log_fail "Permission check failed: Container encountered Permission denied when writing to volume:\n$CONTAINER_LOGS"
fi

if ! echo "$CONTAINER_LOGS" | grep -iq "SUCCESS"; then
    docker rm -f verify_test_gosu_app >/dev/null 2>&1 || true
    log_fail "Log check failed: Container logs do not contain 'SUCCESS'. Logs:\n$CONTAINER_LOGS"
fi

log_pass "Container successfully handled volume permissions and wrote data to volume."

# Clean up
docker rm -f verify_test_gosu_app >/dev/null 2>&1 || true
rm -rf "$TEST_VOL_DIR"

echo "=================================================="
echo -e "${GREEN}ALL VOLUME GOSU PERMISSION CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
