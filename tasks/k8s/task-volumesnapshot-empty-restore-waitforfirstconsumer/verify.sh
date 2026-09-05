#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: VolumeSnapshot Empty Restore (WaitForFirstConsumer Binding) ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if PVC restored-pvc exists
if ! kubectl get pvc restored-pvc -n default >/dev/null 2>&1; then
    echo "ERROR: PVC 'restored-pvc' not found in default namespace."
    exit 1
fi

# 3. Verify restored-pvc status phase is Bound
PVC_STATUS=$(kubectl get pvc restored-pvc -n default -o jsonpath='{.status.phase}')
echo "Current restored-pvc status phase: '$PVC_STATUS'"

if [ "$PVC_STATUS" != "Bound" ]; then
    echo "ERROR: PVC 'restored-pvc' is not Bound. Current status: '$PVC_STATUS'."
    exit 1
fi

# 4. Check readyReplicas for deployment data-app (must be >= 1)
READY_REPLICAS=$(kubectl get deployment data-app -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'data-app' is not ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    exit 1
fi

echo "SUCCESS: PVC 'restored-pvc' is Bound and Deployment 'data-app' is 1/1 READY!"
exit 0
