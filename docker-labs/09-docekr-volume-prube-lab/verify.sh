#!/usr/bin/env bash
set -euo pipefail

# Color Output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

echo "=========================================="
echo " Verifying Docker Volume Prune Lab"
echo "=========================================="

# ---------------------------------------------------------
# Check 1: Count Remaining Unused Volumes
# ---------------------------------------------------------
REMAINING_VOLUMES=$(docker volume ls -q | grep -E '^volume-[0-9]+$' | wc -l | tr -d ' ')

log_info "Found $REMAINING_VOLUMES dangling 'volume-*' entry/entries."

if [[ "$REMAINING_VOLUMES" -gt 0 ]]; then
    log_fail "Cleanup check failed: $REMAINING_VOLUMES dangling volume(s) still exist. Please run 'docker volume prune -f'."
fi

log_pass "All unused dangling volumes successfully pruned."

echo "=========================================="
echo -e "${GREEN}ALL VOLUME PRUNE CHECKS PASSED!${NC}"
echo "=========================================="
exit 0
