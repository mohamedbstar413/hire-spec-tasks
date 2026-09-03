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
echo " Verifying Task: Port Mapping Network Interface Fix"
echo "=================================================="

# 1. Ensure Docker daemon is responsive
log_info "Checking Docker daemon connectivity..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running or responsive."
fi
log_pass "Docker daemon is responsive."

# 2. Check /app/app.py for binding to 0.0.0.0
log_info "Checking /app/app.py interface binding..."
if ! grep -q "0.0.0.0" /app/app.py; then
    log_fail "Code check failed: /app/app.py does not bind to '0.0.0.0'. (Still bound to 127.0.0.1 or default loopback)."
fi
log_pass "/app/app.py is configured to bind to 0.0.0.0."

# 3. Test building image from /app/Dockerfile
log_info "Building image 'myapp:latest' from /app/Dockerfile..."
if ! docker build -t myapp:latest /app >/tmp/docker_build.log 2>&1; then
    log_fail "Failed to build image from /app/Dockerfile. Build log:\n$(cat /tmp/docker_build.log)"
fi
log_pass "Successfully built image 'myapp:latest'."

# 4. Clean up any existing test containers
docker rm -f verify_test_port_app >/dev/null 2>&1 || true

# 5. Run container mapping 8080:3000
log_info "Launching test container mapping host port 8080 to container port 3000..."
if ! docker run -d --name verify_test_port_app -p 8080:3000 myapp:latest >/tmp/docker_run.log 2>&1; then
    log_fail "Failed to launch container: $(cat /tmp/docker_run.log)"
fi

sleep 4

# 6. Test curl http://localhost:8080 from host
log_info "Testing HTTP request to http://localhost:8080..."
HTTP_CODE=$(curl -s -o /tmp/http_out.txt -w "%{http_code}" http://localhost:8080/ || true)

if [[ "$HTTP_CODE" != "200" ]]; then
    LOG_OUTPUT=$(docker logs verify_test_port_app 2>&1 || true)
    docker rm -f verify_test_port_app >/dev/null 2>&1 || true
    log_fail "HTTP test failed! Request to http://localhost:8080 returned status $HTTP_CODE (Expected 200).\nContainer Logs:\n$LOG_OUTPUT"
fi

log_pass "Successfully connected to http://localhost:8080 (HTTP 200 OK)."

# Clean up
docker rm -f verify_test_port_app >/dev/null 2>&1 || true

echo "=================================================="
echo -e "${GREEN}ALL PORT MAPPING CHECKS PASSED!${NC}"
echo "=================================================="
exit 0
