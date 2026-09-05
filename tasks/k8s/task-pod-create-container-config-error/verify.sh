#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Pod Stuck in CreateContainerConfigError ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment api-server exists
if ! kubectl get deployment api-server -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'api-server' not found in default namespace."
    exit 1
fi

# 3. Check readyReplicas for deployment api-server (must be 1)
READY_REPLICAS=$(kubectl get deployment api-server -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'api-server' is not fully ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    exit 1
fi

# 4. Verify no pods matching app=api-server are stuck in CreateContainerConfigError
CONFIG_ERR_PODS=$(kubectl get pods -n default -l app=api-server --no-headers | grep -i "CreateContainerConfigError" | wc -l || true)
if [ "$CONFIG_ERR_PODS" -gt 0 ]; then
    echo "ERROR: Detected $CONFIG_ERR_PODS pod(s) still stuck in CreateContainerConfigError."
    exit 1
fi

# 5. Verify ConfigMap api-config contains key DATABASE_URL
CM_URL=$(kubectl get configmap api-config -n default -o jsonpath='{.data.DATABASE_URL}' 2>/dev/null || true)
if [ -z "$CM_URL" ]; then
    echo "ERROR: ConfigMap 'api-config' is still missing required key 'DATABASE_URL'."
    exit 1
fi

echo "SUCCESS: CreateContainerConfigError resolved! ConfigMap key DATABASE_URL is present and Deployment 'api-server' is 1/1 READY!"
exit 0
