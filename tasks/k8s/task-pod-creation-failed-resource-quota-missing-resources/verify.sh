#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Pod Creation Failed ResourceQuota Missing Resources ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment restricted-app exists
if ! kubectl get deployment restricted-app -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'restricted-app' not found in default namespace."
    exit 1
fi

# 3. Check container resources section in deployment spec
REQ_CPU=$(kubectl get deployment restricted-app -n default -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)
REQ_MEM=$(kubectl get deployment restricted-app -n default -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || true)

if [ -z "$REQ_CPU" ] || [ -z "$REQ_MEM" ]; then
    echo "ERROR: Container 'web-container' is still missing explicit CPU or Memory requests."
    exit 1
fi

# 4. Check readyReplicas for deployment restricted-app (must be 1)
READY_REPLICAS=$(kubectl get deployment restricted-app -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'restricted-app' is not fully ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    exit 1
fi

echo "SUCCESS: ResourceQuota admission error resolved! Container resources specified and Deployment 'restricted-app' is 1/1 READY!"
exit 0
