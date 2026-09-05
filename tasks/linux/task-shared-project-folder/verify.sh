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
echo " Verifying Lab: Shared Project Folder Setup"
echo "=================================================="

BASE_DIR="/home/shared/project-alpha"

# ---------------------------------------------------------
# Check 1: Directory Structure Existence
# ---------------------------------------------------------
log_info "Check 1: Verifying base directory '$BASE_DIR' and subdirectories..."
if [[ ! -d "$BASE_DIR" ]]; then
    log_fail "Base directory '$BASE_DIR' does not exist."
fi

for subdir in src docs output; do
    if [[ ! -d "$BASE_DIR/$subdir" ]]; then
        log_fail "Subdirectory '$BASE_DIR/$subdir' does not exist."
    fi
done
log_pass "Base directory '$BASE_DIR' and subdirectories (src, docs, output) exist."

# ---------------------------------------------------------
# Check 2: Group Ownership
# ---------------------------------------------------------
log_info "Check 2: Verifying group ownership 'alpha-team'..."
DIR_GROUP=$(stat -c "%G" "$BASE_DIR")
if [[ "$DIR_GROUP" != "alpha-team" ]]; then
    log_fail "Directory '$BASE_DIR' group ownership is '$DIR_GROUP'. Expected 'alpha-team'."
fi
log_pass "Group ownership verified as 'alpha-team'."

# ---------------------------------------------------------
# Check 3: Permissions (Owner=rwx, Group=rwx, Others=---)
# ---------------------------------------------------------
log_info "Check 3: Verifying permission masks (770 / 2770) and zero access for others..."
OTHERS_PERM=$(stat -c "%A" "$BASE_DIR" | cut -c 8-10)
if [[ "$OTHERS_PERM" != "---" ]]; then
    log_fail "Others permission on '$BASE_DIR' is '$OTHERS_PERM'. Expected '---' (no access)."
fi

# Check group permissions (must be rwx or rws)
GROUP_PERM=$(stat -c "%A" "$BASE_DIR" | cut -c 5-7)
if [[ "$GROUP_PERM" != "rwx" ]] && [[ "$GROUP_PERM" != "rws" ]] && [[ "$GROUP_PERM" != "rwS" ]]; then
    log_fail "Group permission on '$BASE_DIR' is '$GROUP_PERM'. Expected 'rwx' or 'rws'."
fi
log_pass "Base directory permissions verified (Owner/Group full access, Others denied)."

# ---------------------------------------------------------
# Check 4: Sample Files Existence
# ---------------------------------------------------------
log_info "Check 4: Verifying sample files in subdirectories..."
if [[ ! -f "$BASE_DIR/src/main.c" ]]; then
    log_fail "Sample file '$BASE_DIR/src/main.c' does not exist."
fi

if [[ ! -f "$BASE_DIR/docs/README.md" ]]; then
    log_fail "Sample file '$BASE_DIR/docs/README.md' does not exist."
fi

if [[ ! -f "$BASE_DIR/output/build.log" ]]; then
    log_fail "Sample file '$BASE_DIR/output/build.log' does not exist."
fi
log_pass "Sample files in src, docs, and output verified."

# ---------------------------------------------------------
# Check 5: Inheritance Test (SGID or Default ACL)
# ---------------------------------------------------------
log_info "Check 5: Testing new file group write permission inheritance..."
TEST_FILE="$BASE_DIR/src/verify_inheritance_test.tmp"
rm -f "$TEST_FILE"

su -s /bin/bash devuser -c "touch $TEST_FILE" 2>/dev/null || touch "$TEST_FILE"

if [[ ! -f "$TEST_FILE" ]]; then
    log_fail "Failed to create test file '$TEST_FILE' for inheritance check."
fi

TEST_GROUP=$(stat -c "%G" "$TEST_FILE")
TEST_GROUP_PERM=$(stat -c "%A" "$TEST_FILE" | cut -c 5-7)
rm -f "$TEST_FILE"

if [[ "$TEST_GROUP" != "alpha-team" ]]; then
    log_fail "Newly created file did not inherit group 'alpha-team'. Got group '$TEST_GROUP'."
fi

if [[ "$TEST_GROUP_PERM" != *"rw"* ]]; then
    log_fail "Newly created file does not have group write access. Group perms: '$TEST_GROUP_PERM'."
fi

log_pass "Inheritance test passed! Newly created files inherit group 'alpha-team' and write perms."

echo "=================================================="
echo -e "${GREEN}ALL SHARED PROJECT FOLDER VERIFICATION CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
