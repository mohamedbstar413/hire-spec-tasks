#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: CSI Driver Pod Crashing (Dynamic Provisioning Fails) ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if csi-driver-controller deployment exists in kube-system
if ! kubectl get deployment csi-driver-controller -n kube-system >/dev/null 2>&1; then
    echo "ERROR: Deployment 'csi-driver-controller' not found in namespace kube-system."
    exit 1
fi

# 3. Check readyReplicas for csi-driver-controller (must be >= 1)
READY_REPLICAS=$(kubectl get deployment csi-driver-controller -n kube-system -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current CSI Driver Controller Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'csi-driver-controller' in kube-system is crashing or not ready."
    echo "Check 'kubectl logs -n kube-system deployment/csi-driver-controller' for details."
    exit 1
fi

# 4. Check that pod phase is Running
RUNNING_PODS=$(kubectl get pods -n kube-system -l app=csi-driver-controller --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
if [ -z "$RUNNING_PODS" ]; then
    echo "ERROR: No pods for 'csi-driver-controller' in kube-system are in Running phase."
    exit 1
fi

echo "SUCCESS: CSI Driver pod 'csi-driver-controller' in kube-system fixed and is 1/1 READY!"
exit 0
