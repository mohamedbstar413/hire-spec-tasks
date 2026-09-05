#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Deployment Replicas Mismatch HPA Override ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment web-app-deployment exists
if ! kubectl get deployment web-app-deployment -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'web-app-deployment' not found in default namespace."
    exit 1
fi

# 3. Check HPA minReplicas setting (must be >= 5)
HPA_MIN=$(kubectl get hpa web-app-hpa -n default -o jsonpath='{.spec.minReplicas}' 2>/dev/null || true)
echo "Current HPA minReplicas setting: '$HPA_MIN'"

if [ -z "$HPA_MIN" ] || [ "$HPA_MIN" -lt 5 ]; then
    echo "ERROR: HorizontalPodAutoscaler 'web-app-hpa' minReplicas is '$HPA_MIN', expected 5 or higher."
    exit 1
fi

# 4. Check readyReplicas for deployment web-app-deployment (must be 5)
READY_REPLICAS=$(kubectl get deployment web-app-deployment -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 5"

if [ "$READY_REPLICAS" -lt 5 ]; then
    echo "ERROR: Deployment 'web-app-deployment' is not fully ready. Required: 5/5, Actual: $READY_REPLICAS/5."
    exit 1
fi

echo "SUCCESS: HPA minReplicas updated and Deployment 'web-app-deployment' is 5/5 READY!"
exit 0
