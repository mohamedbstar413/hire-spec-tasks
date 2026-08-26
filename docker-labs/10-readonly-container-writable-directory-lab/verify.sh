#!/usr/bin/env bash
set -euo pipefail

DOCKERFILE_PATH="./Dockerfile"
IMAGE_TAG="candidate-readonly-test:latest"
CONTAINER_NAME="candidate-readonly-test-container"
PORT=8080

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
echo " Verifying Read-Only Container & Writable Directory Lab"
echo "=========================================="

# ---------------------------------------------------------
# Check 1: File Existence
# ---------------------------------------------------------
if [[ ! -f "$DOCKERFILE_PATH" ]]; then
    log_fail "Dockerfile does not exist at $DOCKERFILE_PATH"
fi
log_pass "Dockerfile exists."

# ---------------------------------------------------------
# Check 2: Docker Image Build
# ---------------------------------------------------------
log_info "Building candidate Docker image..."
if ! docker build -t "$IMAGE_TAG" . ; then
    log_fail "Docker image build failed."
fi
log_pass "Docker image built successfully."

# ---------------------------------------------------------
# Check 3: Run Container in Read-Only Mode with Writable Tmpfs Mounts
# ---------------------------------------------------------
log_info "Starting container with --read-only root filesystem..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --read-only \
    --tmpfs /tmp:rw,noexec,nosuid,size=65536k \
    --tmpfs /var/run:rw,noexec,nosuid \
    -p "${PORT}:${PORT}" \
    "$IMAGE_TAG" >/dev/null

sleep 3

# Verify container is running
if ! docker ps -q --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q .; then
    log_info "Container Logs:"
    docker logs "$CONTAINER_NAME" || true
    log_fail "Container failed to run under --read-only root filesystem. Check writable directory configurations."
fi
log_pass "Container is running under read-only root filesystem."

# ---------------------------------------------------------
# Check 4: Verify Root Filesystem Immutability
# ---------------------------------------------------------
log_info "Testing read-only root filesystem restriction..."
IS_READONLY=$(docker exec "$CONTAINER_NAME" sh -c 'touch /test-root-write 2>&1 | grep -i "read-only" || echo "writable"')

if [[ "$IS_READONLY" == "writable" ]]; then
    log_fail "Container security check failed: Root filesystem is writable."
fi
log_pass "Root filesystem immutability verified (writes to / are blocked)."

# ---------------------------------------------------------
# Check 5: Verify Writable Directory Operations (/tmp)
# ---------------------------------------------------------
log_info "Testing writes to designated writable directory (/tmp)..."
WRITABLE_SUCCESS=$(docker exec "$CONTAINER_NAME" sh -c 'touch /tmp/test-write && echo "ok"')

if [[ "$WRITABLE_SUCCESS" != "ok" ]]; then
    log_fail "Writable directory check failed: Cannot write temporary files to /tmp."
fi
log_pass "Writable temporary directory /tmp verified."

echo "=========================================="
echo -e "${GREEN}ALL READ-ONLY CONTAINER CHECKS PASSED!${NC}"
echo "=========================================="
exit 0
