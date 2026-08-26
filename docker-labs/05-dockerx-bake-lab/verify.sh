#!/usr/bin/env bash
set -euo pipefail

BAKE_FILE="./docker-bake.hcl"

# Color Output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# Cleanup built images on exit
cleanup() {
    log_info "Cleaning up built test images..."
    docker rmi -f hire-spec/frontend:latest hire-spec/backend:latest hire-spec/database:latest >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "=========================================="
echo " Verifying Docker Buildx Bake Configuration"
echo "=========================================="

# ---------------------------------------------------------
# Check 1: File Existence
# ---------------------------------------------------------
if [[ ! -f "$BAKE_FILE" ]]; then
    log_fail "docker-bake.hcl does not exist at $BAKE_FILE"
fi
log_pass "docker-bake.hcl exists."

# ---------------------------------------------------------
# Check 2: Static Analysis - Target & Group References
# ---------------------------------------------------------
if grep -q '"worker"' "$BAKE_FILE" ; then
    log_fail "Static analysis failed: docker-bake.hcl still references undefined target 'worker' in group 'default'."
fi

if ! grep -q 'target "database"' "$BAKE_FILE" && ! grep -q 'target "database"' "$BAKE_FILE" ; then
    log_fail "Static analysis failed: Missing 'database' target block."
fi
log_pass "Static analysis verified: Group and target names match."

# ---------------------------------------------------------
# Check 3: Execute Docker Buildx Bake
# ---------------------------------------------------------
log_info "Running 'docker buildx bake --load'..."
if ! docker buildx bake --load ; then
    log_fail "'docker buildx bake --load' failed to execute."
fi
log_pass "Bake execution completed successfully."

# ---------------------------------------------------------
# Check 4: Verify Built Images Exist in Local Docker Daemon
# ---------------------------------------------------------
EXPECTED_IMAGES=(
    "hire-spec/frontend:latest"
    "hire-spec/backend:latest"
    "hire-spec/database:latest"
)

for IMG in "${EXPECTED_IMAGES[@]}"; do
    if ! docker image inspect "$IMG" >/dev/null 2>&1 ; then
        log_fail "Image verification failed: Expected image '$IMG' was not found in Docker daemon."
    fi
    log_pass "Image '$IMG' verified."
done

echo "=========================================="
echo -e "${GREEN}ALL DOCKER BAKE VERIFICATION CHECKS PASSED!${NC}"
echo "=========================================="
exit 0

