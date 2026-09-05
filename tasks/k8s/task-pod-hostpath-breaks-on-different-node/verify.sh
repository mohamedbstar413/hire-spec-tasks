#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Pod hostPath Node Dependency ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment log-processor exists
if ! kubectl get deployment log-processor -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'log-processor' not found in default namespace."
    exit 1
fi

# 3. Verify hostPath is no longer present in deployment volumes
HOST_PATH=$(kubectl get deployment log-processor -n default -o jsonpath='{.spec.template.spec.volumes[*].hostPath}' 2>/dev/null || true)
if [ -n "$HOST_PATH" ]; then
    echo "ERROR: Deployment 'log-processor' is still configured to use a hostPath volume ($HOST_PATH)."
    echo "Replace hostPath volume with emptyDir or a PersistentVolumeClaim to ensure node portability."
    exit 1
fi

# 4. Check readyReplicas for deployment log-processor (must be >= 1)
READY_REPLICAS=$(kubectl get deployment log-processor -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'log-processor' is not ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    exit 1
fi

echo "SUCCESS: Deployment 'log-processor' successfully refactored away from hostPath and is 1/1 READY!"
exit 0
