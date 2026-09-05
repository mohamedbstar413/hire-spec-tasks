#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: PVC ReadWriteOnce Multi-Pod Pending ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment shared-app-deployment exists
if ! kubectl get deployment shared-app-deployment -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'shared-app-deployment' not found in default namespace."
    exit 1
fi

# 3. Check requested replicas count (must be 3)
REPLICAS=$(kubectl get deployment shared-app-deployment -n default -o jsonpath='{.spec.replicas}')
if [ "$REPLICAS" -ne 3 ]; then
    echo "ERROR: Expected deployment spec.replicas to be 3, but found $REPLICAS."
    exit 1
fi

# 4. Check ready replicas count (must be 3)
READY_REPLICAS=$(kubectl get deployment shared-app-deployment -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 3"

if [ "$READY_REPLICAS" -lt 3 ]; then
    echo "ERROR: Deployment 'shared-app-deployment' is not fully ready. Required: 3/3, Actual: $READY_REPLICAS/3."
    exit 1
fi

# 5. Verify no pods matching app=shared-app are stuck in Pending or FailedAttachVolume
PENDING_PODS=$(kubectl get pods -n default -l app=shared-app --no-headers | grep -iE "Pending|ContainerCreating|Error" | wc -l || true)
if [ "$PENDING_PODS" -gt 0 ]; then
    echo "ERROR: Detected $PENDING_PODS pod(s) still stuck in Pending or ContainerCreating status."
    exit 1
fi

# 6. Verify PVC app-data-pvc includes ReadWriteMany in accessModes
PVC_MODES=$(kubectl get pvc app-data-pvc -n default -o jsonpath='{.spec.accessModes}' 2>/dev/null || true)
if ! echo "$PVC_MODES" | grep -q "ReadWriteMany"; then
    echo "ERROR: PersistentVolumeClaim 'app-data-pvc' accessModes is '$PVC_MODES', expected 'ReadWriteMany'."
    exit 1
fi

echo "SUCCESS: PVC accessMode updated to ReadWriteMany! Deployment 'shared-app-deployment' is 3/3 READY!"
exit 0
