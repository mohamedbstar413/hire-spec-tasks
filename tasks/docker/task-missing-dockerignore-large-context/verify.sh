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
echo " Verifying Task: Missing .dockerignore Setup"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check for /app/.dockerignore
log_info "Checking for /app/.dockerignore file..."
if [[ ! -f /app/.dockerignore ]]; then
    log_fail "Check failed: /app/.dockerignore file does not exist."
fi
log_pass "/app/.dockerignore file exists."

# 3. Check contents of /app/.dockerignore
log_info "Inspecting /app/.dockerignore entries..."
DOCKERIGNORE_CONTENT=$(cat /app/.dockerignore)

if ! echo "$DOCKERIGNORE_CONTENT" | grep -iqE "(build_cache|node_modules|\*\.bin)"; then
    log_fail "Check failed: /app/.dockerignore does not exclude 'build_cache', 'node_modules', or '*.bin'."
fi
log_pass "/app/.dockerignore excludes large build artifacts."

# 4. Measure Docker build context size
log_info "Building image 'myapp:latest' from /app and capturing build context size..."
BUILD_OUTPUT=$(docker build -t myapp:latest /app 2>&1 || true)

# Check if image was built successfully
if ! docker inspect myapp:latest >/dev/null 2>&1; then
    log_fail "Failed to build image 'myapp:latest' from /app. Build Output:\n$BUILD_OUTPUT"
fi
log_pass "Successfully built image 'myapp:latest'."

# 5. Verify image size / layer content does NOT contain large_dataset.bin
log_info "Checking if large build artifacts were excluded from the built image..."
CONTAINER_FILES=$(docker run --rm myapp:latest ls -la /app 2>&1 || true)

if echo "$CONTAINER_FILES" | grep -iq "large_dataset.bin" || echo "$CONTAINER_FILES" | grep -iq "vendor_libs.bin"; then
    log_fail "Exclusion check failed: Built image contains excluded binary files ('large_dataset.bin' / 'vendor_libs.bin'). Check .dockerignore patterns."
fi
log_pass "Large binary files successfully excluded from built image."

echo "=================================================="
echo -e "${GREEN}ALL .DOCKERIGNORE CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
