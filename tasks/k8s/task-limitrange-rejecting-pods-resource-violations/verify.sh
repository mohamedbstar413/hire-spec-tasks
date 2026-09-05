#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: LimitRange Rejecting Pods Due to Resource Violations ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment web-service exists
if ! kubectl get deployment web-service -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'web-service' not found in default namespace."
    exit 1
fi

# 3. Check readyReplicas for deployment web-service (must be >= 1)
READY_REPLICAS=$(kubectl get deployment web-service -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'web-service' is not fully ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    echo "Check 'kubectl describe rs' or 'kubectl get events' for LimitRange admission rejection details."
    exit 1
fi

# 4. Check that at least 1 pod is Running and Ready
RUNNING_PODS=$(kubectl get pods -n default -l app=web-service --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
if [ -z "$RUNNING_PODS" ]; then
    echo "ERROR: No pods for deployment 'web-service' are in Running phase."
    exit 1
fi

echo "SUCCESS: LimitRange resource violations fixed and Deployment 'web-service' is 1/1 READY!"
exit 0
