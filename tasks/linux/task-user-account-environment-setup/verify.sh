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
echo " Verifying Lab: User Account & Environment Setup"
echo "=================================================="

# ---------------------------------------------------------
# Check 1: User Existence, Home, and Shell
# ---------------------------------------------------------
log_info "Check 1: Verifying user 'labuser', home directory, and default shell..."
if ! id labuser >/dev/null 2>&1; then
    log_fail "User 'labuser' does not exist."
fi

USER_SHELL=$(getent passwd labuser | cut -d: -f7)
if [[ "$USER_SHELL" != "/bin/bash" ]]; then
    log_fail "User 'labuser' shell is '$USER_SHELL'. Expected '/bin/bash'."
fi

USER_HOME=$(getent passwd labuser | cut -d: -f6)
if [[ ! -d "$USER_HOME" ]]; then
    log_fail "User 'labuser' home directory '$USER_HOME' does not exist."
fi
log_pass "User 'labuser' exists with home '$USER_HOME' and shell '/bin/bash'."

# ---------------------------------------------------------
# Check 2: Forced Password Change on First Login
# ---------------------------------------------------------
log_info "Check 2: Verifying password change forced on first login..."
SHADOW_FIELD=$(getent shadow labuser | cut -d: -f3 || true)

# When forced to change password on first login, shadow 3rd field is 0 or chage shows 'must be changed'
PASS_EXPIRE_STATUS=$(chage -l labuser 2>/dev/null | grep -i "Password must be changed" || true)

if [[ "$SHADOW_FIELD" != "0" ]] && [[ -z "$PASS_EXPIRE_STATUS" ]]; then
    log_fail "Password change is not forced for 'labuser'. Run 'chage -d 0 labuser' or 'passwd -e labuser'."
fi
log_pass "Password change on first login verified for 'labuser'."

# ---------------------------------------------------------
# Check 3: Custom Welcome Message
# ---------------------------------------------------------
log_info "Check 3: Verifying welcome message configuration..."
WELCOME_FOUND=false

if grep -qi "Welcome to the Linux Lab Environment" "$USER_HOME/.bashrc" 2>/dev/null; then
    WELCOME_FOUND=true
elif grep -qi "Welcome to the Linux Lab Environment" /etc/profile.d/*.sh 2>/dev/null; then
    WELCOME_FOUND=true
elif grep -qi "Welcome to the Linux Lab Environment" /etc/motd 2>/dev/null; then
    WELCOME_FOUND=true
fi

if [[ "$WELCOME_FOUND" = false ]]; then
    log_fail "Welcome message 'Welcome to the Linux Lab Environment' not found in $USER_HOME/.bashrc, /etc/motd, or /etc/profile.d/."
fi
log_pass "Custom welcome message verified."

# ---------------------------------------------------------
# Check 4: Workspace Folder Structure & Ownership
# ---------------------------------------------------------
log_info "Check 4: Verifying workspace directory structure and ownership..."
WORKSPACE_DIR="$USER_HOME/workspace"

for folder in projects docs backups; do
    TARGET_PATH="$WORKSPACE_DIR/$folder"
    if [[ ! -d "$TARGET_PATH" ]]; then
        log_fail "Directory '$TARGET_PATH' does not exist."
    fi

    FOLDER_OWNER=$(stat -c "%U:%G" "$TARGET_PATH")
    if [[ "$FOLDER_OWNER" != "labuser:labuser" ]]; then
        log_fail "Directory '$TARGET_PATH' ownership is '$FOLDER_OWNER'. Expected 'labuser:labuser'."
    fi
done
log_pass "Workspace folder structure (projects, docs, backups) verified with ownership labuser:labuser."

echo "=================================================="
echo -e "${GREEN}ALL USER ACCOUNT & ENVIRONMENT VERIFICATION CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
