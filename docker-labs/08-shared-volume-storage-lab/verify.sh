#!/usr/bin/env bash
set -euo pipefail

VOLUME_NAME="shared-volume"

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
echo " Verifying Shared Volume Storage Lab"
echo "=========================================="

# ---------------------------------------------------------
# Check 1: Verify Volume Existence
# ---------------------------------------------------------
if ! docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1 ; then
    log_fail "Volume verification failed: Docker volume '$VOLUME_NAME' does not exist."
fi
log_pass "Shared Docker volume '$VOLUME_NAME' exists."

# ---------------------------------------------------------
# Check 2: Verify Shared File Accessibility Across Containers
# ---------------------------------------------------------
log_info "Verifying shared file presence in volume..."
FILE_EXISTS=$(docker run --rm -v "${VOLUME_NAME}:/shared-data" alpine sh -c '[ -f /shared-data/file.txt ] && echo "yes" || echo "no"')

if [[ "$FILE_EXISTS" != "yes" ]]; then
    log_fail "Shared storage check failed: '/shared-data/file.txt' was not found in shared volume."
fi
log_pass "File '/shared-data/file.txt' exists in shared volume."

# ---------------------------------------------------------
# Check 3: Verify File Content Across Multiple Container Mounts
# ---------------------------------------------------------
CONTENT_C2=$(docker run --rm -v "${VOLUME_NAME}:/shared-data" ubuntu cat /shared-data/file.txt | tr -d '\r')
CONTENT_C3=$(docker run --rm -v "${VOLUME_NAME}:/shared-data" ubuntu cat /shared-data/file.txt | tr -d '\r')

if ! echo "$CONTENT_C2" | grep -q "test file" || ! echo "$CONTENT_C3" | grep -q "test file" ; then
    log_fail "Data consistency check failed: File content does not match 'test file' across container mounts."
fi

log_pass "Data consistency verified across container mounts."

echo "=========================================="
echo -e "${GREEN}ALL SHARED VOLUME STORAGE CHECKS PASSED!${NC}"
echo "=========================================="
exit 0

