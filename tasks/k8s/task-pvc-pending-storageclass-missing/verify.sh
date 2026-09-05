#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: PersistentVolumeClaim Stuck Pending ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if PVC data-pvc exists
if ! kubectl get pvc data-pvc -n default >/dev/null 2>&1; then
    echo "ERROR: PersistentVolumeClaim 'data-pvc' not found in default namespace."
    exit 1
fi

# 3. Check PVC status (must be Bound)
PVC_STATUS=$(kubectl get pvc data-pvc -n default -o jsonpath='{.status.phase}')
if [ "$PVC_STATUS" != "Bound" ]; then
    echo "ERROR: PersistentVolumeClaim 'data-pvc' status is '$PVC_STATUS', expected 'Bound'."
    exit 1
fi

# 4. Check PVC storageClassName (must not be fast-ssd-storage)
SC_NAME=$(kubectl get pvc data-pvc -n default -o jsonpath='{.spec.storageClassName}')
if [ "$SC_NAME" = "fast-ssd-storage" ]; then
    echo "ERROR: PersistentVolumeClaim 'data-pvc' still references non-existent StorageClass 'fast-ssd-storage'."
    exit 1
fi

# 5. Check deployment db-app readyReplicas (must be 1)
READY_REPLICAS=$(kubectl get deployment db-app -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'db-app' is not fully ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    exit 1
fi

echo "SUCCESS: PVC pending issue resolved! PersistentVolumeClaim 'data-pvc' is Bound and Deployment 'db-app' is 1/1 READY!"
exit 0
