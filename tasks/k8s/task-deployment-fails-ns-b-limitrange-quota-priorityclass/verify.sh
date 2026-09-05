#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Deployment Fails in Namespace B (LimitRange + Quota Conflict) ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment app-service exists in namespace ns-b
if ! kubectl get deployment app-service -n ns-b >/dev/null 2>&1; then
    echo "ERROR: Deployment 'app-service' not found in namespace 'ns-b'."
    exit 1
fi

# 3. Verify container resources are explicitly specified in ns-b deployment
REQ_CPU=$(kubectl get deployment app-service -n ns-b -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)
REQ_MEM=$(kubectl get deployment app-service -n ns-b -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || true)

if [ -z "$REQ_CPU" ] || [ -z "$REQ_MEM" ]; then
    echo "ERROR: Deployment 'app-service' in namespace 'ns-b' is still missing explicit CPU/Memory resource requests."
    echo "Without explicit requests, the namespace LimitRange auto-injects 1000m CPU, exceeding ns-b ResourceQuota."
    exit 1
fi

# 4. Check readyReplicas for deployment app-service in namespace ns-b (must be >= 1)
READY_REPLICAS=$(kubectl get deployment app-service -n ns-b -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas in ns-b: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'app-service' in namespace 'ns-b' is not ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    echo "Check 'kubectl describe rs -n ns-b' or 'kubectl describe quota -n ns-b' for details."
    exit 1
fi

echo "SUCCESS: Explicit resource requests configured for 'app-service' in ns-b! Deployment is 1/1 READY in namespace ns-b!"
exit 0
