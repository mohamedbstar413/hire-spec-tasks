#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Service Label Selector Mismatch ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if Service frontend-service exists
if ! kubectl get service frontend-service -n default >/dev/null 2>&1; then
    echo "ERROR: Service 'frontend-service' not found in default namespace."
    exit 1
fi

# 3. Check Service selector to ensure it matches app=web-frontend
SELECTOR_APP=$(kubectl get service frontend-service -n default -o jsonpath='{.spec.selector.app}')
if [ "$SELECTOR_APP" != "web-frontend" ]; then
    echo "ERROR: Service selector 'spec.selector.app' is '$SELECTOR_APP', expected 'web-frontend'."
    exit 1
fi

# 4. Check Service Endpoints (must not be empty or <none>)
ENDPOINTS=$(kubectl get endpoints frontend-service -n default -o jsonpath='{.subsets[*].addresses[*].ip}')
if [ -z "$ENDPOINTS" ]; then
    echo "ERROR: Service 'frontend-service' has 0 active endpoints (ENDPOINTS: <none>)."
    exit 1
fi

ENDPOINT_COUNT=$(echo "$ENDPOINTS" | wc -w || true)
echo "Active Endpoints registered under frontend-service: $ENDPOINT_COUNT"

if [ "$ENDPOINT_COUNT" -lt 3 ]; then
    echo "ERROR: Expected 3 endpoints registered under frontend-service, found $ENDPOINT_COUNT."
    exit 1
fi

# 5. Verify HTTP request to frontend-service returns 200 OK
HTTP_CODE=$(kubectl run test-curl-selector --rm -i --quiet --restart=Never --image=curlimages/curl -- curl -s -o /dev/null -w "%{http_code}" http://frontend-service 2>/dev/null || true)
if [ "$HTTP_CODE" != "200" ]; then
    SERVICE_IP=$(kubectl get service frontend-service -n default -o jsonpath='{.spec.clusterIP}')
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$SERVICE_IP" 2>/dev/null || true)
fi

if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: HTTP request to 'frontend-service' failed with status code '$HTTP_CODE' (expected 200 OK)."
    exit 1
fi

echo "SUCCESS: Service selector mismatch resolved! Service 'frontend-service' successfully routes to 3 pod endpoints!"
exit 0
