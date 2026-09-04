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
echo " Verifying Task: Image Cleanup & Stopped Container"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# Make sure setup_fault script was executed if user hasn't run anything yet
if [[ -f /app/setup_fault.sh ]]; then
    /app/setup_fault.sh >/dev/null 2>&1 || true
fi

# 2. Check if legacy-app:v1 image still exists in docker images
log_info "Checking if 'legacy-app:v1' image has been removed..."
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^legacy-app:v1$"; then
    log_fail "Cleanup check failed: Image 'legacy-app:v1' still exists in 'docker images'."
fi
log_pass "Image 'legacy-app:v1' has been removed from image store."

# 3. Check if stopped_legacy_app container has been removed
log_info "Checking if container 'stopped_legacy_app' has been removed..."
if docker ps -a --format '{{.Names}}' | grep -q "^stopped_legacy_app$"; then
    log_fail "Cleanup check failed: Container 'stopped_legacy_app' still exists in 'docker ps -a'."
fi
log_pass "Stopped container 'stopped_legacy_app' has been removed."

echo "=================================================="
echo -e "${GREEN}ALL IMAGE CLEANUP CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
