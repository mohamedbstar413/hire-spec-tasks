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
echo " Verifying Task: Firewall ICMP Ping Blocking Fix"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# Make sure setup_firewall.sh was executed if user hasn't run anything yet
if [[ -f /app/setup_firewall.sh ]]; then
    /app/setup_firewall.sh >/dev/null 2>&1 || true
fi

# 2. Inspect iptables rules for ICMP DROP
log_info "Inspecting iptables rules for ICMP DROP rules..."
IPTABLES_RULES=$(iptables -S 2>/dev/null || true)

if echo "$IPTABLES_RULES" | grep -qE "(-A|-I)[[:space:]]+(INPUT|FORWARD|DOCKER-USER)[[:space:]].*-p[[:space:]]+icmp.*-j[[:space:]]+DROP"; then
    log_fail "Firewall check failed: iptables still contains a DROP rule for ICMP traffic:\n$(echo "$IPTABLES_RULES" | grep -E 'icmp.*DROP')"
fi
log_pass "No active iptables DROP rules for ICMP traffic found."

# 3. Launch Docker Compose service
log_info "Launching Docker Compose services..."
cd /app
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

$COMPOSE_CMD up -d --build >/tmp/compose_up.log 2>&1 || log_fail "Failed to run '$COMPOSE_CMD up -d'. Output:\n$(cat /tmp/compose_up.log)"
log_pass "Successfully launched Docker Compose services."

sleep 3

# 4. Get container IP and test ICMP ping
CONTAINER_NAME="web_ping_container"
CONTAINER_IP=$(docker inspect "$CONTAINER_NAME" --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "")

if [[ -z "$CONTAINER_IP" ]]; then
    $COMPOSE_CMD down -v >/dev/null 2>&1 || true
    log_fail "Could not determine container IP address."
fi

log_info "Pinging container IP address ($CONTAINER_IP)..."
if ! ping -c 3 -W 3 "$CONTAINER_IP" >/tmp/ping.log 2>&1; then
    $COMPOSE_CMD down -v >/dev/null 2>&1 || true
    log_fail "Ping check failed: Unable to ping container IP $CONTAINER_IP. Ping Output:\n$(cat /tmp/ping.log)"
fi

log_pass "Successfully pinged container IP $CONTAINER_IP with 0% packet loss."

# Clean up
$COMPOSE_CMD down -v >/dev/null 2>&1 || true

echo "=================================================="
echo -e "${GREEN}ALL FIREWALL ICMP CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
