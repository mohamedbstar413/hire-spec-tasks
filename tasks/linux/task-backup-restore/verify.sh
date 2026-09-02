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
echo " Verifying Task: Backup, Corruption & Restore"
echo "=================================================="

# 1. Verify file checksums in /var/www/appdata
log_info "Verifying file integrity against /var/www/appdata/checksums.txt..."
if [[ ! -f /var/www/appdata/checksums.txt ]]; then
    log_fail "Checksum file /var/www/appdata/checksums.txt is missing!"
fi

if ! (cd /var/www/appdata && sha256sum -c checksums.txt >/dev/null 2>&1); then
    log_fail "Checksum verification failed! Data in /var/www/appdata is still corrupted or modified."
fi
log_pass "Data integrity verified! All restored files match original SHA-256 checksums."

# 2. Verify webapp HTTP health check endpoint
log_info "Testing application health check endpoint (http://localhost:5000/health)..."
HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/health || true)

if [[ "$HEALTH_CODE" != "200" ]]; then
    log_fail "Application health check failed: Expected HTTP 200 OK, got HTTP $HEALTH_CODE."
fi
log_pass "Application service is healthy and online (HTTP 200 OK)."

echo "=================================================="
echo -e "${GREEN}ALL BACKUP & RESTORE CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
