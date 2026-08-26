#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="nginx-arm64:latest"

# Color Output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

echo "=========================================="
echo " Verifying ARM64 Multi-Architecture Build"
echo "=========================================="

if ! docker image inspect "$IMAGE_TAG" >/dev/null 2>&1 ; then
    log_fail "Target image '$IMAGE_TAG' does not exist."
fi

ARCH=$(docker inspect -f '{{.Architecture}}' "$IMAGE_TAG" 2>/dev/null || echo "")

if [[ "$ARCH" != "arm64" && "$ARCH" != "aarch64" ]]; then
    log_fail "Expected image architecture 'arm64' or 'aarch64', but got '$ARCH'."
fi

log_pass "Image '$IMAGE_TAG' architecture verified as '$ARCH'."

echo "=========================================="
echo -e "${GREEN}ALL ARM64 BUILD VERIFICATION CHECKS PASSED!${NC}"
echo "=========================================="
exit 0
