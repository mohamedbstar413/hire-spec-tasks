#!/usr/bin/env bash
set -euo pipefail

# Configuration
DOCKERFILE_PATH="./Dockerfile"
APP_PATH="./app.py"
HOST_TEST_FILE="/root/write-here.txt"
IMAGE_TAG="candidate-gosu-test:latest"
CONTAINER_NAME="candidate-gosu-test-container"
PORT=8000

# Color Output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# Cleanup on exit
cleanup() {
    log_info "Cleaning up test container and image..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rmi -f "$IMAGE_TAG" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "=========================================="
echo " Verifying gosu Privilege Dropping Lab"
echo "=========================================="

# ---------------------------------------------------------
# Check 1: File Existence
# ---------------------------------------------------------
if [[ ! -f "$DOCKERFILE_PATH" ]]; then
    log_fail "Dockerfile does not exist at $DOCKERFILE_PATH"
fi
if [[ ! -f "$APP_PATH" ]]; then
    log_fail "app.py does not exist at $APP_PATH"
fi
log_pass "Required source files exist."

# ---------------------------------------------------------
# Check 2: Static Analysis - gosu usage in Dockerfile / scripts
# ---------------------------------------------------------
GOSU_FOUND=false
if grep -iq "gosu" "$DOCKERFILE_PATH" ; then
    GOSU_FOUND=true
fi

# Check for any shell script in current dir referencing gosu
if find . -maxdepth 2 -type f \( -name "*.sh" -o -name "Dockerfile" \) -exec grep -iq "gosu" {} + ; then
    GOSU_FOUND=true
fi

if [[ "$GOSU_FOUND" = false ]]; then
    log_fail "Static analysis failed: No reference to 'gosu' found in Dockerfile or entrypoint scripts."
fi
log_pass "Static analysis verified: 'gosu' installation/usage referenced."

# ---------------------------------------------------------
# Check 3: Prepare Host Restricted File
# ---------------------------------------------------------
log_info "Preparing host restricted file at $HOST_TEST_FILE..."
if [[ ! -f "$HOST_TEST_FILE" ]]; then
    touch "$HOST_TEST_FILE"
fi
chown root:root "$HOST_TEST_FILE" || true
chmod 007 "$HOST_TEST_FILE" || true

# ---------------------------------------------------------
# Check 4: Docker Build Execution
# ---------------------------------------------------------
log_info "Building candidate Docker image..."
if ! docker build -t "$IMAGE_TAG" . ; then
    log_fail "Docker image build failed."
fi
log_pass "Docker image built successfully."

# ---------------------------------------------------------
# Check 5: Run Container with Volume Mount
# ---------------------------------------------------------
log_info "Starting container with root-restricted volume mount..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -p "${PORT}:${PORT}" \
    -v "${HOST_TEST_FILE}:/app/write-here.txt" \
    "$IMAGE_TAG" >/dev/null

sleep 3

# Check if container stays running
if ! docker ps -q --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q .; then
    log_info "Container Logs:"
    docker logs "$CONTAINER_NAME" || true
    log_fail "Container crashed or exited. Startup failed."
fi
log_pass "Container started and is running."

# ---------------------------------------------------------
# Check 6: Runtime Process Owner Verification (MUST NOT BE ROOT)
# ---------------------------------------------------------
PROCESS_UID=$(docker exec "$CONTAINER_NAME" id -u 2>/dev/null || echo "0")

if [[ "$PROCESS_UID" -eq 0 ]]; then
    log_fail "Security check failed: Main container process is running as root (UID 0). Privilege dropping with gosu was not executed."
fi
log_pass "Non-root process execution verified (Running UID: $PROCESS_UID)."

# ---------------------------------------------------------
# Check 7: File Write & HTTP Endpoint Verification
# ---------------------------------------------------------
log_info "Verifying application HTTP endpoint on port $PORT..."
if ! curl -sf "http://localhost:${PORT}/" >/dev/null ; then
    log_info "Container Logs:"
    docker logs "$CONTAINER_NAME" || true
    log_fail "HTTP server check failed on port $PORT."
fi
log_pass "HTTP server responded successfully on port $PORT."

echo "=========================================="
echo -e "${GREEN}ALL GOSU LAB VERIFICATION CHECKS PASSED!${NC}"
echo "=========================================="
exit 0

