#!/usr/bin/env bash
set -euo pipefail

# Configuration
DOCKERFILE_PATH="./Dockerfile"
IMAGE_TAG="candidate-multistage-test:latest"
CONTAINER_NAME="candidate-multistage-test-container"
PORT=3000

# Color Output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# Cleanup on exit (success or failure)
cleanup() {
    log_info "Cleaning up test containers and images..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rmi -f "$IMAGE_TAG" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "=========================================="
echo " Verifying Multi-Stage Dockerfile Lab"
echo "=========================================="

# ---------------------------------------------------------
# Check 1: File Existence
# ---------------------------------------------------------
if [[ ! -f "$DOCKERFILE_PATH" ]]; then
    log_fail "Dockerfile does not exist at $DOCKERFILE_PATH"
fi
log_pass "Dockerfile exists."

# ---------------------------------------------------------
# Check 2: Static Analysis - Check for Multiple FROM instructions
# (Ignores empty lines and comments starting with #)
# ---------------------------------------------------------
FROM_COUNT=$(grep -v '^[[:space:]]*#' "$DOCKERFILE_PATH" | grep -iE '^[[:space:]]*FROM[[:space:]]+' | wc -l | tr -d ' ')

if [[ "$FROM_COUNT" -lt 2 ]]; then
    log_fail "Multi-stage build validation failed: Found $FROM_COUNT 'FROM' statement(s). Expected at least 2."
fi
log_pass "Multi-stage pattern verified: Found $FROM_COUNT 'FROM' stages."

# ---------------------------------------------------------
# Check 3: Static Analysis - Check for COPY --from instruction
# ---------------------------------------------------------
IF_COPY_FROM=$(grep -v '^[[:space:]]*#' "$DOCKERFILE_PATH" | grep -iE '^[[:space:]]*COPY[[:space:]]+--from=' | wc -l | tr -d ' ')

if [[ "$IF_COPY_FROM" -lt 1 ]]; then
    log_fail "Multi-stage build validation failed: No 'COPY --from=...' instruction found to copy artifacts between stages."
fi
log_pass "Stage artifact copy verified: Found 'COPY --from=...' instruction."

# ---------------------------------------------------------
# Check 4: Docker Build Verification
# ---------------------------------------------------------
log_info "Building Docker image..."
if ! docker build -t "$IMAGE_TAG" -f "$DOCKERFILE_PATH" . ; then
    log_fail "Docker image build failed."
fi
log_pass "Docker image built successfully."

# ---------------------------------------------------------
# Check 5: Container Runtime & Health Check Verification
# ---------------------------------------------------------
log_info "Starting container on port $PORT..."
docker run -d --name "$CONTAINER_NAME" -p "${PORT}:${PORT}" "$IMAGE_TAG" >/dev/null

log_info "Waiting for application to start..."
MAX_RETRIES=10
RETRY_COUNT=0
HEALTH_PASSED=false

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if curl -s "http://localhost:${PORT}/health" | grep -q '"status":"UP"'; then
        HEALTH_PASSED=true
        break
    fi
    sleep 1
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [[ "$HEALTH_PASSED" = false ]]; then
    log_info "Container Logs:"
    docker logs "$CONTAINER_NAME" || true
    log_fail "Application health check failed: GET http://localhost:${PORT}/health did not return status 'UP'."
fi

log_pass "Application responded with HTTP 200 OK and status 'UP' on /health."

echo "=========================================="
echo -e "${GREEN}ALL VERIFICATION CHECKS PASSED SUCCESSFULLY!${NC}"
echo "=========================================="
exit 0


