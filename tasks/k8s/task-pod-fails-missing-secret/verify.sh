#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Pod Fails Missing Secret ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if Secret db-credentials exists in namespace default
if ! kubectl get secret db-credentials -n default >/dev/null 2>&1; then
    echo "ERROR: Secret 'db-credentials' not found in default namespace."
    exit 1
fi

# 3. Check keys in Secret db-credentials (must contain username and password)
SECRET_KEYS=$(kubectl get secret db-credentials -n default -o jsonpath='{.data}' 2>/dev/null || true)
if ! echo "$SECRET_KEYS" | grep -q "username" || ! echo "$SECRET_KEYS" | grep -q "password"; then
    echo "ERROR: Secret 'db-credentials' is missing required keys 'username' or 'password'."
    exit 1
fi

# 4. Check deployment secure-backend-api exists
if ! kubectl get deployment secure-backend-api -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'secure-backend-api' not found in default namespace."
    exit 1
fi

# 5. Check readyReplicas for deployment secure-backend-api (must be 1)
READY_REPLICAS=$(kubectl get deployment secure-backend-api -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'secure-backend-api' is not fully ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    exit 1
fi

# 6. Verify no pods matching app=secure-backend-api are stuck in CreateContainerConfigError
ERR_PODS=$(kubectl get pods -n default -l app=secure-backend-api --no-headers | grep -iE "CreateContainerConfigError|CreateContainerError" | wc -l || true)
if [ "$ERR_PODS" -gt 0 ]; then
    echo "ERROR: Detected $ERR_PODS pod(s) still stuck in CreateContainerConfigError."
    exit 1
fi

echo "SUCCESS: Missing secret issue resolved! Secret 'db-credentials' created and Deployment 'secure-backend-api' is 1/1 READY!"
exit 0
