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
echo " Verifying Lab 1: User & Permission Management"
echo "=================================================="

# ---------------------------------------------------------
# Check 1: Group Existence
# ---------------------------------------------------------
log_info "Check 1: Verifying group 'devteam'..."
if ! getent group devteam >/dev/null 2>&1; then
    log_fail "Group 'devteam' does not exist."
fi
log_pass "Group 'devteam' exists."

# ---------------------------------------------------------
# Check 2: Users & Group Membership
# ---------------------------------------------------------
log_info "Check 2: Verifying users (alice, bob, carol) and devteam membership..."
for user in alice bob carol; do
    if ! id "$user" >/dev/null 2>&1; then
        log_fail "User '$user' does not exist."
    fi
    if ! id -nG "$user" | grep -qw "devteam"; then
        log_fail "User '$user' is not a member of group 'devteam'."
    fi
done
log_pass "Users alice, bob, and carol exist and belong to group 'devteam'."

# ---------------------------------------------------------
# Check 3: Directory Creation & Ownership
# ---------------------------------------------------------
TARGET_DIR="/srv/projects/webapp"
log_info "Check 3: Verifying directory $TARGET_DIR and ownership..."
if [[ ! -d "$TARGET_DIR" ]]; then
    log_fail "Directory '$TARGET_DIR' does not exist."
fi

DIR_OWNER=$(stat -c "%U:%G" "$TARGET_DIR")
if [[ "$DIR_OWNER" != "root:devteam" ]]; then
    log_fail "Directory '$TARGET_DIR' ownership is '$DIR_OWNER'. Expected 'root:devteam'."
fi
log_pass "Directory '$TARGET_DIR' exists and is owned by root:devteam."

# ---------------------------------------------------------
# Check 4: SGID Bit Configuration & Functionality
# ---------------------------------------------------------
log_info "Check 4: Verifying SGID bit on $TARGET_DIR..."
PERMS=$(stat -c "%a" "$TARGET_DIR")
# SGID bit is present if mode has 2000 bit set (octal mode starts with 2 or 3, or test -g)
if [[ ! -g "$TARGET_DIR" ]]; then
    log_fail "SGID bit is not set on '$TARGET_DIR' (Permissions: $PERMS). Expected SGID (e.g., 2775 / g+s)."
fi

# Test SGID group inheritance
TEST_FILE="$TARGET_DIR/verify_sgid_test.tmp"
rm -f "$TEST_FILE"
su -s /bin/bash bob -c "touch $TEST_FILE" 2>/dev/null || touch "$TEST_FILE"

FILE_GROUP=$(stat -c "%G" "$TEST_FILE")
rm -f "$TEST_FILE"

if [[ "$FILE_GROUP" != "devteam" ]]; then
    log_fail "New files in '$TARGET_DIR' do not inherit group 'devteam'. Got group '$FILE_GROUP'."
fi
log_pass "SGID bit verified. Newly created files inherit group 'devteam'."

# ---------------------------------------------------------
# Check 5: ACL & Functional Permissions Testing
# ---------------------------------------------------------
log_info "Check 5: Testing ACL rules for alice (RO) and bob (RW)..."

# 5a. Test Bob (Read-Write)
BOB_FILE="$TARGET_DIR/bob_write_test.txt"
rm -f "$BOB_FILE"
if ! su -s /bin/bash bob -c "echo 'hello' > $BOB_FILE" >/dev/null 2>&1; then
    log_fail "User 'bob' was unable to write to '$TARGET_DIR' (Read-Write test failed)."
fi

if ! su -s /bin/bash bob -c "rm -f $BOB_FILE" >/dev/null 2>&1; then
    log_fail "User 'bob' was unable to delete their file in '$TARGET_DIR'."
fi
log_pass "User 'bob' read-write and deletion permissions verified."

# 5b. Test Alice (Read-Only)
ALICE_FILE="$TARGET_DIR/alice_write_test.txt"
rm -f "$ALICE_FILE"
if su -s /bin/bash alice -c "touch $ALICE_FILE" >/dev/null 2>&1; then
    rm -f "$ALICE_FILE"
    log_fail "User 'alice' was able to create a file in '$TARGET_DIR'. Alice must be restricted to Read-Only."
fi
log_pass "User 'alice' read-only restriction verified (write denied)."

# ---------------------------------------------------------
# Check 6: Account Locking Verification
# ---------------------------------------------------------
log_info "Check 6: Verifying carol's account is locked..."
SHADOW_ENTRY=$(getent shadow carol || true)
PASSWD_STATUS=$(passwd -S carol 2>/dev/null || true)

IS_LOCKED=false
if [[ "$PASSWD_STATUS" =~ "L" ]] || [[ "$SHADOW_ENTRY" =~ ^carol:\! ]] || [[ "$SHADOW_ENTRY" =~ ^carol:\* ]]; then
    IS_LOCKED=true
fi

if [[ "$IS_LOCKED" = false ]]; then
    log_fail "User 'carol' account is not locked. Lock account using 'usermod -L carol' or 'passwd -l carol'."
fi
log_pass "User 'carol' account status is verified locked."

echo "=================================================="
echo -e "${GREEN}ALL LAB 1 VERIFICATION CHECKS PASSED SUCCESSFULLY!${NC}"
echo "=================================================="
exit 0
