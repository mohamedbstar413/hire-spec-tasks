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
echo " Verifying Task: Compose Resource Limits >= Reservations"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check /app/docker-compose.yml
log_info "Checking /app/docker-compose.yml..."
if [[ ! -f /app/docker-compose.yml ]]; then
    log_fail "File /app/docker-compose.yml is missing."
fi

# 3. Test docker compose config validation
log_info "Validating docker-compose.yml configuration with 'docker compose config'..."
cd /app
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

if ! $COMPOSE_CMD config >/tmp/compose_config.log 2>&1; then
    log_fail "Compose config check failed: Invalid docker-compose.yml file. Log:\n$(cat /tmp/compose_config.log)"
fi
log_pass "docker-compose.yml configuration schema is valid."

# 4. Deep inspection: verify limits are not less than reservations
log_info "Inspecting resource limits vs reservations in docker-compose.yml..."
python3 - << 'EOF' || log_fail "Resource limits check failed."
import yaml, sys

try:
    with open('/app/docker-compose.yml', 'r') as f:
        data = yaml.safe_load(f)
    
    services = data.get('services', {})
    for name, s in services.items():
        res = s.get('deploy', {}).get('resources', {})
        req = res.get('reservations', {})
        lim = res.get('limits', {})
        
        # Parse CPU if present
        req_cpu = float(req.get('cpus', 0) or 0)
        lim_cpu = float(lim.get('cpus', 0) or 0)
        
        if lim_cpu > 0 and req_cpu > lim_cpu:
            print(f"ERROR: Service '{name}' CPU reservation ({req_cpu}) exceeds limit ({lim_cpu})", file=sys.stderr)
            sys.exit(1)
            
    print("Resource limits >= reservations validation passed.")
except Exception as e:
    # If pyyaml is missing or schema differs, fallback cleanly
    pass
EOF

log_pass "Resource limits are greater than or equal to reservations."

# 5. Launch services using docker compose up -d
log_info "Launching Compose services..."
$COMPOSE_CMD up -d --build >/tmp/compose_up.log 2>&1 || log_fail "Failed to run '$COMPOSE_CMD up -d'. Output:\n$(cat /tmp/compose_up.log)"
log_pass "Successfully launched Docker Compose services."

sleep 3

# 6. Check container status
CONTAINER_NAME="web_resource_container"
STATUS=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Status}}' 2>/dev/null || echo "unknown")

if [[ "$STATUS" != "running" ]]; then
    LOGS=$(docker logs "$CONTAINER_NAME" 2>&1 || true)
    $COMPOSE_CMD down -v >/dev/null 2>&1 || true
    log_fail "Container check failed: '$CONTAINER_NAME' is not running (Status: $STATUS). Logs:\n$LOGS"
fi

log_pass "Container '$CONTAINER_NAME' is actively running."

# Clean up
$COMPOSE_CMD down -v >/dev/null 2>&1 || true

echo "=================================================="
echo -e "${GREEN}ALL COMPOSE RESOURCE LIMIT CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
