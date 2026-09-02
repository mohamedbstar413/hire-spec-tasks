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
echo " Verifying Task: Cron Job Execution Fix"
echo "=================================================="

# 1. Clean existing backups in /var/backups/app to test fresh execution
log_info "Cleaning /var/backups/app to test non-interactive execution..."
rm -f /var/backups/app/db-backup.sql.zst

# 2. Simulate strict cron environment execution (minimal PATH, clean environment)
log_info "Executing /opt/scripts/backup.sh under strict cron environment (env -i PATH=/usr/bin:/bin)..."
if ! env -i PATH=/usr/bin:/bin /bin/sh /opt/scripts/backup.sh >/tmp/cron_test.log 2>&1; then
    log_fail "Non-interactive execution failed! Script output:\n$(cat /tmp/cron_test.log)"
fi

# 3. Check if backup file was created
log_info "Checking if /var/backups/app/db-backup.sql.zst exists..."
if [[ ! -f /var/backups/app/db-backup.sql.zst ]]; then
    log_fail "Backup check failed: /var/backups/app/db-backup.sql.zst was not created."
fi

# 4. Check if backup file is non-empty and valid zstd
log_info "Validating backup archive content and integrity..."
if [[ ! -s /var/backups/app/db-backup.sql.zst ]]; then
    log_fail "Backup check failed: /var/backups/app/db-backup.sql.zst is an empty (0 byte) file."
fi

if ! zstd -t /var/backups/app/db-backup.sql.zst >/dev/null 2>&1; then
    log_fail "Backup check failed: /var/backups/app/db-backup.sql.zst is not a valid zstd archive."
fi

log_pass "Backup file verified! Archive is valid and non-empty."

echo "=================================================="
echo -e "${GREEN}ALL CRON JOB FIX CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
