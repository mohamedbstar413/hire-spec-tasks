#!/usr/bin/env bash
set -euo pipefail

# Color Output Formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

echo "=================================================="
echo " Verifying Lab: Organizing and Archiving Project Work"
echo "=================================================="

BASE_DIR="/srv/project-files"

# ---------------------------------------------------------
# Check 1: Directory Structure & Sorting
# ---------------------------------------------------------
log_info "Check 1: Verifying subdirectories (docs, scripts, logs)..."
for dir in docs scripts logs; do
    if [[ ! -d "$BASE_DIR/$dir" ]]; then
        log_fail "Subdirectory '$BASE_DIR/$dir' does not exist."
    fi
done
log_pass "Subdirectories docs, scripts, and logs exist."

log_info "Check 2: Verifying sorted file locations..."
if [[ ! -f "$BASE_DIR/docs/notes.txt" ]] && [[ ! -f "$BASE_DIR/docs/readme.txt" ]]; then
    log_fail "Text files (.txt) were not moved into '$BASE_DIR/docs/'."
fi

if [[ ! -f "$BASE_DIR/scripts/deploy.sh" ]] && [[ ! -f "$BASE_DIR/scripts/build.sh" ]]; then
    log_fail "Shell scripts (.sh) were not moved into '$BASE_DIR/scripts/'."
fi

if [[ ! -f "$BASE_DIR/logs/server.log" ]] && [[ ! -f "$BASE_DIR/logs/debug.log" ]]; then
    log_fail "Log files (.log) were not moved into '$BASE_DIR/logs/'."
fi
log_pass "Files are properly sorted into designated subdirectories."

# ---------------------------------------------------------
# Check 3: Removal of .tmp Files
# ---------------------------------------------------------
log_info "Check 3: Verifying removal of temporary (.tmp) files..."
TMP_COUNT=$(find "$BASE_DIR" -maxdepth 2 -name "*.tmp" | wc -l)
if [[ "$TMP_COUNT" -gt 0 ]]; then
    log_fail "Found $TMP_COUNT remaining .tmp files in '$BASE_DIR'. Temporary files must be removed."
fi
log_pass "Temporary .tmp files successfully cleaned up."

# ---------------------------------------------------------
# Check 4: Backup Archive Creation
# ---------------------------------------------------------
BACKUP_DIR="/var/backups/projects"
log_info "Check 4: Verifying backup archive in '$BACKUP_DIR'..."

if [[ ! -d "$BACKUP_DIR" ]]; then
    log_fail "Backup directory '$BACKUP_DIR' does not exist."
fi

ARCHIVE_FILE=$(find "$BACKUP_DIR" -maxdepth 1 -name "project-files-*.tar.gz" -o -name "project-files.tar.gz" -o -name "*.tar.gz" | head -n 1)

if [[ -z "$ARCHIVE_FILE" ]] || [[ ! -f "$ARCHIVE_FILE" ]]; then
    log_fail "No tar.gz backup archive found in '$BACKUP_DIR'."
fi

log_info "Testing archive integrity of '$ARCHIVE_FILE'..."
if ! tar -tzf "$ARCHIVE_FILE" >/dev/null 2>&1; then
    log_fail "Archive '$ARCHIVE_FILE' is invalid or not a valid gzip tar file."
fi
log_pass "Valid backup archive '$ARCHIVE_FILE' verified."

echo "=================================================="
echo -e "${GREEN}ALL ORGANIZING AND ARCHIVING VERIFICATION CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
