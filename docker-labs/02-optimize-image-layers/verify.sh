#!/usr/bin/env bash
set -euo pipefail

# Configuration
DOCKERFILE_PATH="./Dockerfile"
IMAGE_TAG="candidate-layer-opt-test:latest"
CONTAINER_NAME="candidate-layer-opt-container"
MAX_SIZE_MB=400
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
echo " Verifying Image Layer & Size Optimization"
echo "=========================================="

# ---------------------------------------------------------
# Check 1: File Existence
# ---------------------------------------------------------
if [[ ! -f "$DOCKERFILE_PATH" ]]; then
    log_fail "Dockerfile does not exist at $DOCKERFILE_PATH"
fi
log_pass "Dockerfile exists."

# ---------------------------------------------------------
# Check 2: Static Analysis - Multi-Stage FROM statements
# ---------------------------------------------------------
FROM_COUNT=$(grep -v '^[[:space:]]*#' "$DOCKERFILE_PATH" | grep -iE '^[[:space:]]*FROM[[:space:]]+' | wc -l | tr -d ' ')

if [[ "$FROM_COUNT" -lt 2 ]]; then
    log_fail "Multi-stage validation failed: Found $FROM_COUNT 'FROM' statement(s). Expected at least 2 for stage separation."
fi
log_pass "Multi-stage pattern verified ($FROM_COUNT stages found)."

# ---------------------------------------------------------
# Check 3: Static Analysis - COPY --from transfer
# ---------------------------------------------------------
IF_COPY_FROM=$(grep -v '^[[:space:]]*#' "$DOCKERFILE_PATH" | grep -iE '^[[:space:]]*COPY[[:space:]]+--from=' | wc -l | tr -d ' ')

if [[ "$IF_COPY_FROM" -lt 1 ]]; then
    log_fail "Multi-stage validation failed: Missing 'COPY --from=...' statement to copy built JAR from build stage."
fi
log_pass "Stage artifact copy instruction verified ('COPY --from=' found)."

# ---------------------------------------------------------
# Check 4: Docker Build Execution
# ---------------------------------------------------------
log_info "Building optimized Docker image from Dockerfile..."
if ! docker build -t "$IMAGE_TAG" -f "$DOCKERFILE_PATH" . ; then
    log_fail "Docker build failed."
fi
log_pass "Docker image built successfully."

# ---------------------------------------------------------
# Check 5: Image Size Optimization Check (< 400 MB)
# ---------------------------------------------------------
IMAGE_BYTES=$(docker inspect -f '{{.Size}}' "$IMAGE_TAG")
IMAGE_SIZE_MB=$((IMAGE_BYTES / 1024 / 1024))

log_info "Built Image Size: ${IMAGE_SIZE_MB} MB (Maximum allowed threshold: ${MAX_SIZE_MB} MB)"

if [[ "$IMAGE_SIZE_MB" -gt "$MAX_SIZE_MB" ]]; then
    log_fail "Image size optimization failed: Image size is ${IMAGE_SIZE_MB} MB, which exceeds threshold of ${MAX_SIZE_MB} MB."
fi
log_pass "Image size optimization verified (${IMAGE_SIZE_MB} MB < ${MAX_SIZE_MB} MB)."

# ---------------------------------------------------------
# Check 6: Non-Root User Verification
# ---------------------------------------------------------
CONTAINER_USER=$(docker inspect -f '{{.Config.User}}' "$IMAGE_TAG")
if [[ -z "$CONTAINER_USER" || "$CONTAINER_USER" == "root" || "$CONTAINER_USER" == "0" ]]; then
    log_fail "Security check failed: Container is configured to run as root user. Please use a non-root user (e.g. USER spring)."
fi
log_pass "Non-root user configuration verified (Configured User: '${CONTAINER_USER}')."

# ---------------------------------------------------------
# Check 7: Container Startup Verification
# ---------------------------------------------------------
log_info "Starting container on port $PORT..."
docker run -d --name "$CONTAINER_NAME" -p "${PORT}:${PORT}" "$IMAGE_TAG" >/dev/null

log_info "Waiting for Java application to initialize..."
sleep 5

if ! docker ps -q --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q .; then
    log_info "Container Logs:"
    docker logs "$CONTAINER_NAME" || true
    log_fail "Container failed to remain running after startup."
fi

log_pass "Container started and is running successfully."

echo "=========================================="
echo -e "${GREEN}ALL OPTIMIZATION VERIFICATION CHECKS PASSED!${NC}"
echo "=========================================="
exit 0
