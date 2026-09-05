#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: NetworkPolicy Pod Communication Blocked ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if frontend deployment exists
if ! kubectl get deployment frontend -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'frontend' not found in default namespace."
    exit 1
fi

# 3. Check if backend-service exists
if ! kubectl get service backend-service -n default >/dev/null 2>&1; then
    echo "ERROR: Service 'backend-service' not found in default namespace."
    exit 1
fi

echo "Testing HTTP connection from frontend pod to http://backend-service:8080..."

# 4. Execute HTTP request inside frontend pod to backend-service:8080
RESPONSE=$(kubectl exec deployment/frontend -n default -- curl -s --connect-timeout 4 http://backend-service:8080 2>/dev/null || true)

echo "Received Response: '$RESPONSE'"

if ! echo "$RESPONSE" | grep -q "200 OK"; then
    echo "ERROR: HTTP connection from frontend pod to backend-service timed out or failed."
    exit 1
fi

# 5. Verify NetworkPolicy permits app=frontend ingress
NETPOL_SPEC=$(kubectl get netpol backend-netpol -n default -o jsonpath='{.spec.ingress[*].from[*].podSelector.matchLabels.app}' 2>/dev/null || true)

# If policy deleted or updated to allow frontend
if [ -n "$NETPOL_SPEC" ] && [ "$NETPOL_SPEC" != "frontend" ]; then
    echo "WARNING: NetworkPolicy backend-netpol podSelector app is '$NETPOL_SPEC', expected 'frontend' or open access."
fi

echo "SUCCESS: NetworkPolicy blocking issue resolved! Pod 'frontend' successfully connects to 'backend-service:8080'!"
exit 0
