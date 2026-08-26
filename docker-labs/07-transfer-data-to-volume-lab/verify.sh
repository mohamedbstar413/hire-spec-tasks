#!/usr/bin/env bash
set -euo pipefail

VOLUME_NAME="my-data-volume"

# Color Output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# Cleanup volume on exit
cleanup() {
    log_info "Cleaning up test volume..."
    docker volume rm -f "$VOLUME_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "=========================================="
echo " Verifying Data Transfer to Docker Volume"
echo "=========================================="

# ---------------------------------------------------------
# Check 1: Verify Volume Existence
# ---------------------------------------------------------
if ! docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1 ; then
    log_fail "Volume verification failed: Docker volume '$VOLUME_NAME' does not exist."
fi
log_pass "Docker named volume '$VOLUME_NAME' exists."

# ---------------------------------------------------------
# Check 2: Verify File Existence in Volume
# ---------------------------------------------------------
log_info "Checking volume contents for readable.txt..."
FILE_EXISTS=$(docker run --rm -v "${VOLUME_NAME}:/vol" alpine sh -c '[ -f /vol/readable.txt ] && echo "yes" || echo "no"')

if [[ "$FILE_EXISTS" != "yes" ]]; then
    log_fail "Data verification failed: 'readable.txt' was not found inside volume '$VOLUME_NAME'."
fi
log_pass "'readable.txt' found inside volume."

# ---------------------------------------------------------
# Check 3: Verify File Content Integrity
# ---------------------------------------------------------
FILE_CONTENT=$(docker run --rm -v "${VOLUME_NAME}:/vol" alpine cat /vol/readable.txt | tr -d '\r')

if ! echo "$FILE_CONTENT" | grep -q "readable text file" ; then
    log_fail "Data integrity check failed: Expected 'readable text file' content, but got '$FILE_CONTENT'."
fi

log_pass "File content integrity verified: '$FILE_CONTENT'."

echo "=========================================="
echo -e "${GREEN}ALL VOLUME DATA TRANSFER CHECKS PASSED!${NC}"
echo "=========================================="
exit 0

