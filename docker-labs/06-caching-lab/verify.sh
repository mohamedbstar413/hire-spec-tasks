#!/usr/bin/env bash
set -euo pipefail

DOCKERFILE_PATH="./Dockerfile"
IMAGE_TAG="candidate-caching-test:latest"
CONTAINER_NAME="candidate-caching-test-container"

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
    log_info "Cleaning up test container and images..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rmi -f "$IMAGE_TAG" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "=========================================="
echo " Verifying Docker Layer Caching Lab"
echo "=========================================="

# ---------------------------------------------------------
# Check 1: File Existence
# ---------------------------------------------------------
if [[ ! -f "$DOCKERFILE_PATH" ]]; then
    log_fail "Dockerfile does not exist at $DOCKERFILE_PATH"
fi
log_pass "Dockerfile exists."

# ---------------------------------------------------------
# Check 2: Static Analysis - Instruction Ordering
# ---------------------------------------------------------
# Get line numbers of key instructions (ignoring comments)
PACKAGE_COPY_LINE=$(grep -n -iE '^[[:space:]]*COPY[[:space:]]+.*package' "$DOCKERFILE_PATH" | head -n 1 | cut -d: -f1 || echo "")
NPM_INSTALL_LINE=$(grep -n -iE '^[[:space:]]*RUN[[:space:]]+npm[[:space:]]+install' "$DOCKERFILE_PATH" | head -n 1 | cut -d: -f1 || echo "")
ALL_COPY_LINE=$(grep -n -iE '^[[:space:]]*COPY[[:space:]]+(\.[[:space:]]+\.|app\.js)' "$DOCKERFILE_PATH" | tail -n 1 | cut -d: -f1 || echo "")

if [[ -z "$PACKAGE_COPY_LINE" ]]; then
    log_fail "Caching check failed: Dockerfile does not explicitly COPY package.json before installing dependencies."
fi

if [[ -z "$NPM_INSTALL_LINE" ]]; then
    log_fail "Caching check failed: Missing 'RUN npm install' instruction in Dockerfile."
fi

if [[ "$PACKAGE_COPY_LINE" -gt "$NPM_INSTALL_LINE" ]]; then
    log_fail "Caching check failed: 'COPY package.json' must occur BEFORE 'RUN npm install'."
fi

if [[ -n "$ALL_COPY_LINE" && "$ALL_COPY_LINE" -lt "$NPM_INSTALL_LINE" ]]; then
    log_fail "Caching check failed: Source code COPY instruction occurs BEFORE 'RUN npm install', invalidating the cache."
fi

log_pass "Static analysis verified: package.json is copied before 'RUN npm install'."

# ---------------------------------------------------------
# Check 3: Dynamic Cache Verification Test
# ---------------------------------------------------------
log_info "Performing initial image build (populating build cache)..."
if ! docker build -t "$IMAGE_TAG" . >/dev/null 2>&1 ; then
    log_fail "Initial Docker build failed."
fi
log_pass "Initial build completed."

log_info "Simulating source code modification in app.js..."
touch app.js

log_info "Performing second image build (verifying layer cache hit)..."
BUILD_LOG=$(docker build -t "$IMAGE_TAG" . 2>&1)

if echo "$BUILD_LOG" | grep -iE 'RUN npm install' | grep -vqE 'CACHED|Using cache' ; then
    # If the step RUN npm install was re-executed instead of using cache
    log_fail "Cache verification failed: 'RUN npm install' was re-executed instead of hitting the cache after app.js was modified."
fi

log_pass "Dynamic cache test verified: 'RUN npm install' step hit the cache!"

# ---------------------------------------------------------
# Check 4: Runtime Test
# ---------------------------------------------------------
log_info "Testing container runtime..."
docker run -d --name "$CONTAINER_NAME" -p 3000:3000 "$IMAGE_TAG" >/dev/null
sleep 2

if ! curl -sf "http://localhost:3000/health" >/dev/null ; then
    log_fail "Runtime verification failed: Health endpoint http://localhost:3000/health failed."
fi

log_pass "Container runtime and HTTP endpoint verified."

echo "=========================================="
echo -e "${GREEN}ALL CACHING LAB VERIFICATION CHECKS PASSED!${NC}"
echo "=========================================="
exit 0

