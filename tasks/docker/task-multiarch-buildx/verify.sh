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
echo " Verifying Task: Multi-Architecture Buildx Build"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check if /app/myapp-multiarch.tar exists
ARCHIVE_PATH="/app/myapp-multiarch.tar"
log_info "Checking for multi-architecture image archive at $ARCHIVE_PATH..."

if [[ ! -f "$ARCHIVE_PATH" ]]; then
    # Fallback check: check if buildx imagetools or docker history contains multiarch build
    log_fail "File check failed: Archive '$ARCHIVE_PATH' does not exist. Make sure to export using '--output type=oci,dest=/app/myapp-multiarch.tar'."
fi

log_pass "Found multi-architecture image archive: $ARCHIVE_PATH."

# 3. Inspect archive contents for OCI index.json or tar manifests
log_info "Inspecting archive structure for multi-platform manifests..."
TMP_DIR="/tmp/multiarch_verify_$$"
mkdir -p "$TMP_DIR"

tar -xf "$ARCHIVE_PATH" -C "$TMP_DIR" 2>/dev/null || true

HAS_AMD64=false
HAS_ARM64=false

if [[ -f "$TMP_DIR/index.json" ]]; then
    log_info "Analyzing OCI index.json..."
    INDEX_CONTENT=$(cat "$TMP_DIR/index.json")
    
    if echo "$INDEX_CONTENT" | grep -iq "amd64"; then
        HAS_AMD64=true
    fi
    if echo "$INDEX_CONTENT" | grep -iq "arm64"; then
        HAS_ARM64=true
    fi
fi

# Deep inspection: check blobs for architecture strings
if [[ "$HAS_AMD64" == "false" || "$HAS_ARM64" == "false" ]]; then
    log_info "Deep inspecting archive manifest blobs for architecture definitions..."
    BLOB_SEARCH=$(grep -r -i -E "(amd64|x86_64)" "$TMP_DIR/" || true)
    if [[ -n "$BLOB_SEARCH" ]]; then
        HAS_AMD64=true
    fi

    BLOB_ARM_SEARCH=$(grep -r -i -E "(arm64|aarch64)" "$TMP_DIR/" || true)
    if [[ -n "$BLOB_ARM_SEARCH" ]]; then
        HAS_ARM64=true
    fi
fi

rm -rf "$TMP_DIR"

if [[ "$HAS_AMD64" != "true" ]]; then
    log_fail "Architecture check failed: Image archive does not contain linux/amd64 build manifest."
fi
log_pass "Verified linux/amd64 platform manifest present in archive."

if [[ "$HAS_ARM64" != "true" ]]; then
    log_fail "Architecture check failed: Image archive does not contain linux/arm64 build manifest."
fi
log_pass "Verified linux/arm64 platform manifest present in archive."

echo "=================================================="
echo -e "${GREEN}ALL MULTI-ARCHITECTURE BUILD CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
