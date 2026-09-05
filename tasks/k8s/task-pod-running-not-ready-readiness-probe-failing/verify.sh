#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Pod Running But Not Ready (Readiness Probe Failing) ==="

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

# 3. Verify readiness probe path is updated from /healthz
PROBE_PATH=$(kubectl get deployment api-server -n default -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null || true)
if [ "$PROBE_PATH" = "/healthz" ]; then
    echo "ERROR: Readiness probe path is still set to non-existent endpoint '/healthz'."
    exit 1
fi

# 4. Check readyReplicas for deployment api-server (must be >= 1)
READY_REPLICAS=$(kubectl get deployment api-server -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'api-server' is not ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    echo "Check 'kubectl describe pod -l app=api-server' for readiness probe event errors."
    exit 1
fi

echo "SUCCESS: Readiness probe path updated to valid endpoint and Deployment 'api-server' is 1/1 READY!"
exit 0
