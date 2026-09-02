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
echo " Verifying Task: Reclaim Phantom Disk Space"
echo "=================================================="

# 1. Verify /exam/mnt is mounted
if ! mountpoint -q /exam/mnt 2>/dev/null; then
    log_fail "Mount check failed: /exam/mnt is not mounted."
fi

# 2. Check for remaining unlinked/deleted open file handles on /exam/mnt
log_info "Checking for open handles on deleted files in /exam/mnt..."
DELETED_HANDLES=$(lsof +L1 /exam/mnt 2>/dev/null | grep -i "deleted" || true)
if [[ -n "$DELETED_HANDLES" ]]; then
    log_fail "Process check failed: A process is still holding open handles to deleted files on /exam/mnt:\n$DELETED_HANDLES"
fi
log_pass "No process is holding deleted file descriptors on /exam/mnt."

# 3. Check disk usage percentage on /exam/mnt
log_info "Checking disk usage percentage on /exam/mnt..."
USE_PCT=$(df -P /exam/mnt | awk 'NR==2 {print $5}' | tr -d '%')

if [[ -z "$USE_PCT" ]]; then
    log_fail "Could not determine disk usage for /exam/mnt."
fi

if (( USE_PCT > 20 )); then
    log_fail "Disk space check failed: /exam/mnt disk usage is ${USE_PCT}% (expected < 20%)."
fi

log_pass "Disk space reclaimed successfully! Current /exam/mnt usage is ${USE_PCT}%."

echo "=================================================="
echo -e "${GREEN}ALL PHANTOM DISK SPACE CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
