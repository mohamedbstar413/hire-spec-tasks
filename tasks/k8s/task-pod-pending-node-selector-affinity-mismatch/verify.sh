#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Pod Pending Node Selector Mismatch ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment analytics-worker exists
if ! kubectl get deployment analytics-worker -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'analytics-worker' not found in default namespace."
    exit 1
fi

# 3. Check readyReplicas for deployment analytics-worker (must be 1)
READY_REPLICAS=$(kubectl get deployment analytics-worker -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'analytics-worker' is not fully ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    exit 1
fi

# 4. Verify no pods matching app=analytics-worker are stuck in Pending
PENDING_PODS=$(kubectl get pods -n default -l app=analytics-worker --no-headers | grep -i "Pending" | wc -l || true)
if [ "$PENDING_PODS" -gt 0 ]; then
    echo "ERROR: Detected $PENDING_PODS pod(s) still stuck in Pending status."
    exit 1
fi

echo "SUCCESS: Node selector mismatch resolved! Deployment 'analytics-worker' is scheduled and 1/1 READY!"
exit 0
